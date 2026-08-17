import 'dart:async';

import 'package:get/get.dart';

import '../../../domains/download_task.dart';
import '../../../domains/engine_info.dart';
import '../../../services/download_dialog_service.dart';
import '../../../services/engine_service.dart';
import '../../../services/task_service.dart';
import '../../routes/app_pages.dart';

class OverviewController extends GetxController {
  OverviewController({required this.engineService, required this.taskService});

  final EngineService engineService;
  final TaskService taskService;
  Worker? _engineWorker;

  int get totalSpeed =>
      taskService.tasks.fold<int>(0, (total, task) => total + task.speedBps);

  int get activeCount => taskService.tasks.where(_isTransferring).length;

  int get queuedCount => taskService.tasks.where(_isQueuedOrPaused).length;

  int get completedCount => taskService.tasks
      .where((task) => task.state == DownloadTaskState.completed)
      .length;

  int get issueCount => taskService.tasks
      .where((task) => task.state == DownloadTaskState.failed)
      .length;

  List<DownloadTask> get currentTasks {
    final values = taskService.tasks
        .where((task) => _isTransferring(task) || _isQueuedOrPaused(task))
        .toList(growable: false);
    values.sort((left, right) {
      final priority = _statePriority(
        left.state,
      ).compareTo(_statePriority(right.state));
      if (priority != 0) return priority;
      return right.updatedAt.compareTo(left.updatedAt);
    });
    return values.take(4).toList(growable: false);
  }

  List<DownloadTask> get recentTasks {
    final values = taskService.tasks.toList(growable: false)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return values.take(5).toList(growable: false);
  }

  @override
  void onInit() {
    super.onInit();
    if (engineService.state.value == EngineConnectionState.online) {
      _scheduleTaskStart();
    }
    _engineWorker = ever(engineService.state, (state) {
      if (state == EngineConnectionState.online) {
        _scheduleTaskStart();
      }
    });
  }

  void _scheduleTaskStart() {
    scheduleMicrotask(() => unawaited(taskService.start()));
  }

  @override
  Future<void> refresh() async {
    if (engineService.state.value != EngineConnectionState.online) {
      await engineService.refresh();
    }
    if (engineService.state.value == EngineConnectionState.online) {
      await taskService.start();
    }
  }

  Future<void> openCreateDownload() => DownloadDialogService.to.open();

  Future<void> pasteDownload() => DownloadDialogService.to.paste();

  void viewAllTasks() => Get.offAllNamed<void>(Routes.tasks);

  void openTask(DownloadTask task) =>
      Get.toNamed<void>(Routes.taskDetailFor(task.id));

  bool _isTransferring(DownloadTask task) =>
      task.state == DownloadTaskState.downloading ||
      task.state == DownloadTaskState.retrying;

  bool _isQueuedOrPaused(DownloadTask task) =>
      task.state == DownloadTaskState.queued ||
      task.state == DownloadTaskState.paused;

  int _statePriority(DownloadTaskState state) => switch (state) {
    DownloadTaskState.downloading => 0,
    DownloadTaskState.retrying => 1,
    DownloadTaskState.queued => 2,
    DownloadTaskState.paused => 3,
    DownloadTaskState.completed ||
    DownloadTaskState.failed ||
    DownloadTaskState.canceled => 4,
  };

  @override
  void onClose() {
    _engineWorker?.dispose();
    super.onClose();
  }
}
