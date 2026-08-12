import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../data/clients/engine_client.dart';
import '../../../domains/batch_task_result.dart';
import '../../../domains/bt_resolution.dart';
import '../../../domains/download_resolution.dart';
import '../../../domains/download_task.dart';
import '../../../services/directory_picker.dart';
import '../../../services/engine_settings_service.dart';
import '../../../services/torrent_file_picker.dart';

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
    this.engineSettingsService,
    this.torrentFilePicker = const SystemTorrentFilePicker(),
    String initialUrl = '',
  }) : urlController = TextEditingController(text: initialUrl);

  final EngineClient client;
  final DirectoryPicker directoryPicker;
  final EngineSettingsService? engineSettingsService;
  final TorrentFilePicker torrentFilePicker;
  final TextEditingController urlController;
  final TextEditingController explicitPeersController = TextEditingController();
  final FocusNode urlFocusNode = FocusNode(debugLabel: 'download-url');
  final phase = CreateDownloadPhase.idle.obs;
  final resolution = Rxn<DownloadResolution>();
  final btResolution = Rxn<BTResolution>();
  final selectedBTFileIndexes = <int>{}.obs;
  final torrentFileName = RxnString();
  final explicitPeersInput = ''.obs;
  final peerInputError = RxnString();
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
  final isPickingTorrent = false.obs;
  final isCanceling = false.obs;
  final isUpdatingTask = false.obs;
  List<int>? _torrentMetadata;
  StreamSubscription<DownloadTaskEvent>? _eventSubscription;

  bool get isResolving => phase.value == CreateDownloadPhase.resolving;
  bool get isBusy =>
      phase.value == CreateDownloadPhase.resolving ||
      phase.value == CreateDownloadPhase.creating ||
      isPickingDirectory.value ||
      isPickingTorrent.value ||
      isCanceling.value ||
      isUpdatingTask.value;
  bool get isBatchMode =>
      sourceUrls.length > 1 ||
      resolveFailures.isNotEmpty ||
      resolutions.length > 1;
  bool get canCreateTask =>
      phase.value == CreateDownloadPhase.resolved &&
      btResolution.value == null &&
      resolutions.isNotEmpty &&
      saveDirectory.value?.isNotEmpty == true;
  bool get hasBTResolution => btResolution.value != null;
  bool get hasTorrentMetadata => _torrentMetadata?.isNotEmpty == true;
  List<String> get explicitPeers =>
      _parseExplicitPeers(explicitPeersInput.value);
  bool get canCreateBTTask {
    final bt = btResolution.value;
    return phase.value == CreateDownloadPhase.resolved &&
        bt?.sourceType == BTSourceType.torrent &&
        hasTorrentMetadata &&
        selectedBTFileIndexes.isNotEmpty &&
        saveDirectory.value?.isNotEmpty == true &&
        explicitPeers.isNotEmpty &&
        peerInputError.value == null;
  }

  bool get allBTFilesSelected {
    final files = btResolution.value?.files ?? const <BTFileEntry>[];
    return files.isNotEmpty &&
        files.every((file) => selectedBTFileIndexes.contains(file.index));
  }

  int get selectedBTFileCount => selectedBTFileIndexes.length;
  int get selectedBTSize {
    final selected = selectedBTFileIndexes;
    return btResolution.value?.files
            .where((file) => selected.contains(file.index))
            .fold<int>(0, (total, file) => total + file.size) ??
        0;
  }

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
    saveDirectory.value = engineSettingsService?.defaultDownloadDirectory;
    if (saveDirectory.value == null && engineSettingsService != null) {
      unawaited(_loadDefaultDownloadDirectory());
    }
    hasInput.value = urlController.text.trim().isNotEmpty;
    urlController.addListener(_onURLChanged);
    explicitPeersController.addListener(_onExplicitPeersChanged);
  }

  Future<void> _loadDefaultDownloadDirectory() async {
    final loaded = await engineSettingsService?.load();
    final directory = loaded?.defaultDownloadDirectory;
    if (saveDirectory.value == null && directory?.isNotEmpty == true) {
      saveDirectory.value = directory;
    }
  }

  void _onURLChanged() {
    hasInput.value = urlController.text.trim().isNotEmpty;
    if (task.value == null &&
        (phase.value == CreateDownloadPhase.resolved ||
            phase.value == CreateDownloadPhase.batchCreated ||
            phase.value == CreateDownloadPhase.failed)) {
      phase.value = CreateDownloadPhase.idle;
      _clearResolvedSourceState();
      errorMessage.value = null;
      actionError.value = null;
    }
  }

  Future<void> resolve() async {
    if (isResolving) return;
    final inputs = _parseURLs(urlController.text);
    _clearResolvedSourceState();
    if (inputs.isEmpty) {
      errorMessage.value = L10nKeys.createInvalidUrl.tr;
      phase.value = CreateDownloadPhase.failed;
      urlFocusNode.requestFocus();
      return;
    }
    if (inputs.length > maxTaskBatchSize) {
      errorMessage.value = L10nKeys.createBatchLimit.tr;
      phase.value = CreateDownloadPhase.failed;
      urlFocusNode.requestFocus();
      return;
    }

    if (inputs.length == 1 && _isMagnet(inputs.single)) {
      await _resolveMagnet(inputs.single);
      return;
    }
    if (inputs.any(_isMagnet)) {
      errorMessage.value = L10nKeys.createBTMixedInput.tr;
      phase.value = CreateDownloadPhase.failed;
      return;
    }

    errorMessage.value = null;
    sourceUrls.assignAll(inputs);
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

  Future<void> chooseTorrentFile() async {
    if (isPickingTorrent.value || isBusy) return;
    isPickingTorrent.value = true;
    errorMessage.value = null;
    actionError.value = null;
    try {
      final selected = await torrentFilePicker.chooseTorrent();
      if (selected == null) return;
      _clearResolvedSourceState();
      phase.value = CreateDownloadPhase.resolving;
      final resolved = await client.resolveTorrent(selected.bytes);
      _torrentMetadata = List<int>.unmodifiable(selected.bytes);
      _applyBTResolution(resolved, fileName: selected.name);
    } on TorrentFileTooLargeException {
      errorMessage.value = L10nKeys.createBTMetadataTooLarge.tr;
      phase.value = CreateDownloadPhase.failed;
    } on EngineClientException catch (error) {
      errorMessage.value = _btMessageFor(error);
      phase.value = CreateDownloadPhase.failed;
    } on Object {
      errorMessage.value = L10nKeys.createBTTorrentError.tr;
      phase.value = CreateDownloadPhase.failed;
    } finally {
      isPickingTorrent.value = false;
    }
  }

  Future<void> _resolveMagnet(String value) async {
    errorMessage.value = null;
    sourceUrls.assignAll(<String>[value]);
    phase.value = CreateDownloadPhase.resolving;
    try {
      _applyBTResolution(await client.resolveMagnet(value));
    } on EngineClientException catch (error) {
      errorMessage.value = _btMessageFor(error);
      phase.value = CreateDownloadPhase.failed;
    } on Object {
      errorMessage.value = L10nKeys.createBTMagnetError.tr;
      phase.value = CreateDownloadPhase.failed;
    }
  }

  void _applyBTResolution(BTResolution value, {String? fileName}) {
    btResolution.value = value;
    torrentFileName.value = fileName;
    selectedBTFileIndexes.assignAll(value.files.map((file) => file.index));
    actionError.value = null;
    phase.value = CreateDownloadPhase.resolved;
  }

  void _clearResolvedSourceState() {
    resolution.value = null;
    resolutions.clear();
    btResolution.value = null;
    selectedBTFileIndexes.clear();
    torrentFileName.value = null;
    _torrentMetadata = null;
    explicitPeersController.clear();
    explicitPeersInput.value = '';
    peerInputError.value = null;
    sourceUrls.clear();
    resolveFailures.clear();
    batchResult.value = null;
    createdTasks.clear();
  }

  void toggleBTFile(int index) {
    if (!selectedBTFileIndexes.remove(index)) {
      selectedBTFileIndexes.add(index);
    }
  }

  void toggleAllBTFiles() {
    final files = btResolution.value?.files ?? const <BTFileEntry>[];
    if (files.isEmpty) return;
    if (allBTFilesSelected) {
      selectedBTFileIndexes.clear();
    } else {
      selectedBTFileIndexes.assignAll(files.map((file) => file.index));
    }
  }

  void _onExplicitPeersChanged() {
    explicitPeersInput.value = explicitPeersController.text;
    peerInputError.value = _validateExplicitPeers(explicitPeersController.text);
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
    if (metadata.isEmpty ||
        btResolution.value != null ||
        phase.value != CreateDownloadPhase.resolved) {
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

  Future<void> createBTTask() async {
    final metadata = _torrentMetadata;
    final directory = saveDirectory.value;
    if (metadata == null ||
        metadata.isEmpty ||
        phase.value != CreateDownloadPhase.resolved ||
        btResolution.value?.sourceType != BTSourceType.torrent) {
      return;
    }
    if (selectedBTFileIndexes.isEmpty) {
      actionError.value = L10nKeys.createBTFilesRequired.tr;
      return;
    }
    if (directory == null || directory.isEmpty) {
      actionError.value = L10nKeys.createDirectoryRequired.tr;
      return;
    }
    final peerError = _validateExplicitPeers(explicitPeersController.text);
    peerInputError.value = peerError;
    if (peerError != null) {
      actionError.value = peerError;
      return;
    }

    actionError.value = null;
    phase.value = CreateDownloadPhase.creating;
    try {
      final created = await client.createBTTask(
        metadata: metadata,
        saveDirectory: directory,
        selectedFileIndexes: selectedBTFileIndexes.toList()..sort(),
        explicitPeers: explicitPeers,
      );
      _applyTask(created);
      _subscribeToTaskEvents();
    } on EngineClientException catch (error) {
      actionError.value = _taskActionMessage(error);
      phase.value = CreateDownloadPhase.resolved;
    } on Object {
      actionError.value = L10nKeys.createTaskError.tr;
      phase.value = CreateDownloadPhase.resolved;
    }
  }

  Future<void> pauseTask() => _updateTask(client.pauseTask);

  Future<void> resumeTask() => _updateTask(client.resumeTask);

  Future<void> _updateTask(
    Future<DownloadTask> Function(String id) action,
  ) async {
    final current = task.value;
    if (current == null || isUpdatingTask.value) return;
    isUpdatingTask.value = true;
    actionError.value = null;
    try {
      _applyTask(await action(current.id));
    } on EngineClientException catch (error) {
      actionError.value = _taskActionMessage(error);
    } on Object {
      actionError.value = L10nKeys.createTaskActionError.tr;
    } finally {
      isUpdatingTask.value = false;
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
        'bt_transfer_unavailable' => L10nKeys.createBTUnavailable.tr,
        'bt_peer_required' => L10nKeys.createBTPeerRequired.tr,
        'bt_peer_invalid' => L10nKeys.createBTPeerInvalid.tr,
        'bt_file_selection_invalid' => L10nKeys.createBTFilesRequired.tr,
        'bt_metadata_invalid' => L10nKeys.createBTTorrentError.tr,
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

  bool _isMagnet(String value) =>
      Uri.tryParse(value)?.scheme.toLowerCase() == 'magnet';

  List<String> _parseExplicitPeers(String value) => value
      .split(RegExp(r'[,\r\n]+'))
      .map((peer) => peer.trim())
      .where((peer) => peer.isNotEmpty)
      .toSet()
      .toList(growable: false);

  String? _validateExplicitPeers(String value) {
    final peers = _parseExplicitPeers(value);
    if (peers.isEmpty) return L10nKeys.createBTPeerRequired.tr;
    if (peers.length > 80) return L10nKeys.createBTPeerLimit.tr;
    for (final peer in peers) {
      final separator = peer.lastIndexOf(':');
      if (separator <= 0 || separator == peer.length - 1) {
        return L10nKeys.createBTPeerInvalid.tr;
      }
      final host = peer.substring(0, separator);
      final port = int.tryParse(peer.substring(separator + 1));
      final octets = host.split('.').map(int.tryParse).toList(growable: false);
      if (port == null ||
          port < 1 ||
          port > 65535 ||
          octets.length != 4 ||
          octets.any((octet) => octet == null || octet < 0 || octet > 255)) {
        return L10nKeys.createBTPeerInvalid.tr;
      }
      final first = octets[0]!;
      final second = octets[1]!;
      final third = octets[2]!;
      final restricted =
          first == 0 ||
          first == 10 ||
          first == 127 ||
          first >= 224 ||
          (first == 100 && second >= 64 && second <= 127) ||
          (first == 169 && second == 254) ||
          (first == 172 && second >= 16 && second <= 31) ||
          (first == 192 && second == 168) ||
          (first == 192 && second == 0 && third == 0) ||
          (first == 192 && second == 0 && third == 2) ||
          (first == 198 && (second == 18 || second == 19)) ||
          (first == 198 && second == 51 && third == 100) ||
          (first == 203 && second == 0 && third == 113);
      if (restricted) return L10nKeys.createBTPeerRestricted.tr;
    }
    return null;
  }

  String _btMessageFor(EngineClientException error) => switch (error.code) {
    'bt_invalid_magnet' => L10nKeys.createBTInvalidMagnet.tr,
    'bt_metadata_too_large' => L10nKeys.createBTMetadataTooLarge.tr,
    'bt_path_unsafe' => L10nKeys.createBTPathUnsafe.tr,
    'bt_file_limit' => L10nKeys.createBTFileLimit.tr,
    'bt_size_limit' => L10nKeys.createBTSizeLimit.tr,
    'bt_tracker_invalid' => L10nKeys.createBTTrackerInvalid.tr,
    'engine_unreachable' => L10nKeys.createEngineOffline.tr,
    _ =>
      error.retryable
          ? L10nKeys.createResolveError.tr
          : L10nKeys.createBTTorrentError.tr,
  };

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
    explicitPeersController
      ..removeListener(_onExplicitPeersChanged)
      ..dispose();
    urlFocusNode.dispose();
    super.onClose();
  }
}
