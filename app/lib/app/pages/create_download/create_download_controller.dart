import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../data/clients/engine_client.dart';
import '../../../domains/batch_task_result.dart';
import '../../../domains/download_resolution.dart';
import '../../../domains/download_task.dart';
import '../../../services/directory_picker.dart';

enum CreateDownloadPhase {
  idle,
  resolving,
  resolved,
  creating,
  batchCreated,
  queued,
  downloading,
  retrying,
  paused,
  completed,
  failed,
  canceled,
}

class BatchResolveFailure {
  const BatchResolveFailure({required this.url, required this.message});

  final String url;
  final String message;
}

class BatchCreationFailure {
  const BatchCreationFailure({required this.fileName, required this.message});

  final String fileName;
  final String message;
}

class CreateDownloadController extends GetxController {
  CreateDownloadController({
    required this.client,
    required this.directoryPicker,
    String initialUrl = '',
  }) : urlController = TextEditingController(text: initialUrl);

  final EngineClient client;
  final DirectoryPicker directoryPicker;
  final TextEditingController urlController;
  final FocusNode urlFocusNode = FocusNode(debugLabel: 'download-url');
  final phase = CreateDownloadPhase.idle.obs;
  final resolution = Rxn<DownloadResolution>();
  final resolutions = <DownloadResolution>[].obs;
  final sourceUrls = <String>[].obs;
  final resolveFailures = <BatchResolveFailure>[].obs;
  final batchResult = Rxn<BatchTaskResult>();
  final createdTasks = <DownloadTask>[].obs;
  final task = Rxn<DownloadTask>();
  final errorMessage = RxnString();
  final actionError = RxnString();
  final saveDirectory = RxnString();
  final hasInput = false.obs;
  final isPickingDirectory = false.obs;
  final isCanceling = false.obs;
  StreamSubscription<DownloadTaskEvent>? _eventSubscription;

  bool get isResolving => phase.value == CreateDownloadPhase.resolving;
  bool get isBusy =>
      phase.value == CreateDownloadPhase.resolving ||
      phase.value == CreateDownloadPhase.creating ||
      isPickingDirectory.value ||
      isCanceling.value;
  bool get isBatchMode =>
      sourceUrls.length > 1 ||
      resolveFailures.isNotEmpty ||
      resolutions.length > 1;
  bool get canCreateTask =>
      phase.value == CreateDownloadPhase.resolved &&
      resolutions.isNotEmpty &&
      saveDirectory.value?.isNotEmpty == true;
  List<BatchCreationFailure> get batchCreationFailures {
    final result = batchResult.value;
    if (result == null) return const <BatchCreationFailure>[];
    return result.items
        .where((item) => item.error != null)
        .map((item) {
          final fileName = item.index < resolutions.length
              ? resolutions[item.index].fileName
              : L10nKeys.createUnknown.tr;
          return BatchCreationFailure(
            fileName: fileName,
            message: _batchTaskErrorMessage(item.error!),
          );
        })
        .toList(growable: false);
  }

  @override
  void onInit() {
    super.onInit();
    hasInput.value = urlController.text.trim().isNotEmpty;
    urlController.addListener(_onURLChanged);
  }

  void _onURLChanged() {
    hasInput.value = urlController.text.trim().isNotEmpty;
    if (task.value == null &&
        (phase.value == CreateDownloadPhase.resolved ||
            phase.value == CreateDownloadPhase.batchCreated ||
            phase.value == CreateDownloadPhase.failed)) {
      phase.value = CreateDownloadPhase.idle;
      resolution.value = null;
      resolutions.clear();
      sourceUrls.clear();
      resolveFailures.clear();
      batchResult.value = null;
      createdTasks.clear();
      errorMessage.value = null;
      actionError.value = null;
    }
  }

  Future<void> resolve() async {
    if (isResolving) return;
    final inputs = _parseURLs(urlController.text);
    if (inputs.isEmpty) {
      resolution.value = null;
      resolutions.clear();
      errorMessage.value = L10nKeys.createInvalidUrl.tr;
      phase.value = CreateDownloadPhase.failed;
      urlFocusNode.requestFocus();
      return;
    }
    if (inputs.length > maxTaskBatchSize) {
      resolution.value = null;
      resolutions.clear();
      errorMessage.value = L10nKeys.createBatchLimit.tr;
      phase.value = CreateDownloadPhase.failed;
      urlFocusNode.requestFocus();
      return;
    }

    errorMessage.value = null;
    resolution.value = null;
    resolutions.clear();
    sourceUrls.assignAll(inputs);
    resolveFailures.clear();
    batchResult.value = null;
    createdTasks.clear();
    phase.value = CreateDownloadPhase.resolving;
    for (final input in inputs) {
      final validationError = _validateURL(input);
      if (validationError != null) {
        resolveFailures.add(
          BatchResolveFailure(url: input, message: validationError),
        );
        continue;
      }
      try {
        resolutions.add(await client.resolveDownload(input));
      } on EngineClientException catch (error) {
        resolveFailures.add(
          BatchResolveFailure(url: input, message: _messageFor(error)),
        );
      } on Object {
        resolveFailures.add(
          BatchResolveFailure(
            url: input,
            message: L10nKeys.createResolveError.tr,
          ),
        );
      }
    }
    if (resolutions.isEmpty) {
      errorMessage.value = resolveFailures.length == 1
          ? resolveFailures.single.message
          : L10nKeys.createBatchResolveNone.tr;
      phase.value = CreateDownloadPhase.failed;
      return;
    }
    resolution.value = resolutions.first;
    actionError.value = null;
    phase.value = CreateDownloadPhase.resolved;
  }

  Future<void> chooseSaveDirectory() async {
    if (isPickingDirectory.value) return;
    isPickingDirectory.value = true;
    actionError.value = null;
    try {
      final selected = await directoryPicker.chooseDirectory(
        initialDirectory: saveDirectory.value,
      );
      if (selected != null && selected.trim().isNotEmpty) {
        saveDirectory.value = selected.trim();
      }
    } on Object {
      actionError.value = L10nKeys.createDirectoryError.tr;
    } finally {
      isPickingDirectory.value = false;
    }
  }

  Future<void> createTask() async {
    final metadata = resolutions.toList(growable: false);
    final directory = saveDirectory.value;
    if (metadata.isEmpty || phase.value != CreateDownloadPhase.resolved) {
      return;
    }
    if (directory == null || directory.isEmpty) {
      actionError.value = L10nKeys.createDirectoryRequired.tr;
      return;
    }

    actionError.value = null;
    phase.value = CreateDownloadPhase.creating;
    try {
      if (isBatchMode) {
        final result = await client.createTasks(
          metadata
              .map(
                (item) => CreateTaskInput(
                  url: item.url,
                  fileName: item.fileName,
                  saveDirectory: directory,
                  expectedSize: item.size,
                  acceptRanges: item.acceptRanges,
                  etag: item.etag,
                  lastModified: item.lastModified,
                ),
              )
              .toList(growable: false),
        );
        batchResult.value = result;
        createdTasks.assignAll(result.successfulTasks);
        phase.value = CreateDownloadPhase.batchCreated;
      } else {
        final item = metadata.single;
        final created = await client.createTask(
          url: item.url,
          fileName: item.fileName,
          saveDirectory: directory,
          expectedSize: item.size,
          acceptRanges: item.acceptRanges,
          etag: item.etag,
          lastModified: item.lastModified,
        );
        _applyTask(created);
        _subscribeToTaskEvents();
      }
    } on EngineClientException catch (error) {
      actionError.value = _taskActionMessage(error);
      phase.value = CreateDownloadPhase.resolved;
    } on Object {
      actionError.value = L10nKeys.createTaskError.tr;
      phase.value = CreateDownloadPhase.resolved;
    }
  }

  Future<void> cancelTask() async {
    final current = task.value;
    if (current == null || !current.canCancel || isCanceling.value) {
      return;
    }
    isCanceling.value = true;
    actionError.value = null;
    try {
      _applyTask(await client.cancelTask(current.id));
    } on EngineClientException catch (error) {
      actionError.value = _taskActionMessage(error);
    } on Object {
      actionError.value = L10nKeys.createCancelError.tr;
    } finally {
      isCanceling.value = false;
    }
  }

  void _subscribeToTaskEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = client.watchTaskEvents().listen(
      (event) {
        final current = task.value;
        if (event.type == 'task.updated' &&
            current != null &&
            event.task.id == current.id) {
          _applyTask(event.task);
        }
      },
      onError: (_) {
        if (_isActivelyManaged(task.value)) {
          actionError.value = L10nKeys.createEventsInterrupted.tr;
        }
      },
      onDone: () {
        if (_isActivelyManaged(task.value)) {
          actionError.value = L10nKeys.createEventsInterrupted.tr;
        }
      },
    );
  }

  void _applyTask(DownloadTask value) {
    task.value = value;
    phase.value = switch (value.state) {
      DownloadTaskState.queued => CreateDownloadPhase.queued,
      DownloadTaskState.downloading => CreateDownloadPhase.downloading,
      DownloadTaskState.retrying => CreateDownloadPhase.retrying,
      DownloadTaskState.paused => CreateDownloadPhase.paused,
      DownloadTaskState.completed => CreateDownloadPhase.completed,
      DownloadTaskState.failed => CreateDownloadPhase.failed,
      DownloadTaskState.canceled => CreateDownloadPhase.canceled,
    };
    if (value.isTerminal) {
      _eventSubscription?.cancel();
      _eventSubscription = null;
    }
  }

  bool _isActivelyManaged(DownloadTask? value) =>
      value != null &&
      (value.state == DownloadTaskState.queued ||
          value.state == DownloadTaskState.downloading ||
          value.state == DownloadTaskState.retrying);

  String _taskActionMessage(EngineClientException error) =>
      switch (error.code) {
        'invalid_destination' => L10nKeys.createDirectoryError.tr,
        'destination_exists' => L10nKeys.createDestinationExists.tr,
        'engine_unreachable' => L10nKeys.createEngineOffline.tr,
        'invalid_task_state' => L10nKeys.createCancelError.tr,
        _ =>
          error.retryable
              ? L10nKeys.createTaskError.tr
              : L10nKeys.createResponseError.tr,
      };

  String get taskFailureMessage => switch (task.value?.error?.code) {
    'destination_exists' => L10nKeys.taskDestinationExists.tr,
    'invalid_destination' => L10nKeys.taskInvalidDestination.tr,
    'remote_rejected' => L10nKeys.taskRemoteRejected.tr,
    'remote_resource_changed' => L10nKeys.taskRemoteChanged.tr,
    'resume_not_supported' => L10nKeys.taskResumeNotSupported.tr,
    'partial_file_changed' => L10nKeys.taskPartialFileChanged.tr,
    'file_consistency_failed' => L10nKeys.taskFileConsistencyFailed.tr,
    'atomic_publish_failed' => L10nKeys.taskAtomicPublishFailed.tr,
    _ => L10nKeys.taskDownloadFailed.tr,
  };

  String _batchTaskErrorMessage(BatchTaskError error) => switch (error.code) {
    'destination_exists' => L10nKeys.createDestinationExists.tr,
    'invalid_destination' => L10nKeys.createDirectoryError.tr,
    'invalid_request' => L10nKeys.createInvalidUrl.tr,
    'unsupported_scheme' => L10nKeys.createInvalidScheme.tr,
    _ => L10nKeys.createTaskError.tr,
  };

  List<String> _parseURLs(String value) {
    final unique = <String>{};
    for (final line in value.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) unique.add(trimmed);
    }
    return unique.toList(growable: false);
  }

  String? _validateURL(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return L10nKeys.createInvalidUrl.tr;
    }
    if (uri.scheme.toLowerCase() != 'http' &&
        uri.scheme.toLowerCase() != 'https') {
      return L10nKeys.createInvalidScheme.tr;
    }
    return null;
  }

  String _messageFor(EngineClientException error) => switch (error.code) {
    'invalid_request' => L10nKeys.createInvalidUrl.tr,
    'unsupported_scheme' => L10nKeys.createInvalidScheme.tr,
    'engine_unreachable' => L10nKeys.createEngineOffline.tr,
    'resolve_failed' => L10nKeys.createResolveError.tr,
    _ =>
      error.retryable
          ? L10nKeys.createResolveError.tr
          : L10nKeys.createResponseError.tr,
  };

  @override
  void onClose() {
    _eventSubscription?.cancel();
    urlController
      ..removeListener(_onURLChanged)
      ..dispose();
    urlFocusNode.dispose();
    super.onClose();
  }
}
