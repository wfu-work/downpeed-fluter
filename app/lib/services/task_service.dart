import 'dart:async';

import 'package:get/get.dart';

import '../data/clients/engine_client.dart';
import '../domains/batch_task_result.dart';
import '../domains/download_task.dart';
import 'desktop_actions_service.dart';

class TaskService extends GetxService {
  TaskService({required this.client, required this.desktopActions});

  static TaskService get to => Get.find<TaskService>();

  final EngineClient client;
  final DesktopActionsService desktopActions;
  final tasks = <DownloadTask>[].obs;
  final isLoading = false.obs;
  final actionTaskIds = <String>{}.obs;
  final errorMessage = RxnString();
  final eventErrorMessage = RxnString();

  StreamSubscription<DownloadTaskEvent>? _eventSubscription;
  bool _watching = false;

  DownloadTask? taskById(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<void> start() async {
    _watchEvents();
    await refresh();
  }

  Future<void> refresh() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      _replaceTasks(await client.fetchTasks());
    } on EngineClientException catch (error) {
      errorMessage.value = error.message;
    } on Object {
      errorMessage.value = 'Could not load download tasks.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<DownloadTask?> loadTask(String id) async {
    final existing = taskById(id);
    if (existing != null) return existing;
    try {
      final task = await client.fetchTask(id);
      _upsert(task);
      return task;
    } on EngineClientException catch (error) {
      errorMessage.value = error.message;
    } on Object {
      errorMessage.value = 'Could not load the download task.';
    }
    return null;
  }

  bool isActing(String id) => actionTaskIds.contains(id);

  Future<void> pause(String id) => _perform(id, client.pauseTask);

  Future<void> resume(String id) => _perform(id, client.resumeTask);

  Future<void> cancel(String id) => _perform(id, client.cancelTask);

  Future<BatchTaskResult?> actOnTasks(
    Iterable<String> ids,
    BatchTaskAction action,
  ) async {
    final taskIds = ids.toSet().take(maxTaskBatchSize).toList(growable: false);
    if (taskIds.isEmpty || taskIds.any(isActing)) return null;
    actionTaskIds.addAll(taskIds);
    errorMessage.value = null;
    try {
      final result = await client.actOnTasks(taskIds, action);
      for (final task in result.successfulTasks) {
        _upsert(task);
      }
      return result;
    } on EngineClientException catch (error) {
      errorMessage.value = error.message;
    } on Object {
      errorMessage.value = 'The engine could not update the selected tasks.';
    } finally {
      actionTaskIds.removeAll(taskIds);
    }
    return null;
  }

  Future<void> _perform(
    String id,
    Future<DownloadTask> Function(String id) action,
  ) async {
    if (isActing(id)) return;
    actionTaskIds.add(id);
    errorMessage.value = null;
    try {
      _upsert(await action(id));
    } on EngineClientException catch (error) {
      errorMessage.value = error.message;
    } on Object {
      errorMessage.value = 'The engine could not update this task.';
    } finally {
      actionTaskIds.remove(id);
    }
  }

  void _watchEvents() {
    if (_watching) return;
    _watching = true;
    _eventSubscription = client.watchTaskEvents().listen(
      (event) {
        if (event.type == 'task.updated') {
          eventErrorMessage.value = null;
          final previous = taskById(event.task.id);
          _upsert(event.task);
          if (previous != null &&
              previous.state != DownloadTaskState.completed &&
              event.task.state == DownloadTaskState.completed) {
            unawaited(desktopActions.notifyCompleted(event.task));
          }
        }
      },
      onError: (_) {
        eventErrorMessage.value =
            'Live progress was interrupted. Refresh to reconcile tasks.';
        _watching = false;
      },
      onDone: () {
        _watching = false;
      },
    );
  }

  void _replaceTasks(Iterable<DownloadTask> values) {
    final sorted = values.toList()..sort(_newestFirst);
    tasks.assignAll(sorted);
  }

  void _upsert(DownloadTask value) {
    final updated = tasks.toList();
    final index = updated.indexWhere((task) => task.id == value.id);
    if (index < 0) {
      updated.add(value);
    } else {
      updated[index] = value;
    }
    _replaceTasks(updated);
  }

  int _newestFirst(DownloadTask left, DownloadTask right) =>
      right.createdAt.compareTo(left.createdAt);

  @override
  void onClose() {
    _eventSubscription?.cancel();
    super.onClose();
  }
}
