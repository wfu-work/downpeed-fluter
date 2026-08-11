import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../domains/batch_task_result.dart';
import '../../../services/engine_service.dart';
import '../../../services/desktop_actions_service.dart';
import '../../../services/task_service.dart';
import '../../../domains/download_task.dart';
import '../../../domains/engine_info.dart';
import '../create_download/create_download_view.dart';
import '../../routes/app_pages.dart';

enum TaskListFilter { all, active, completed, issues }

enum TaskListSort { newest, oldest, name, progress, size }

class TaskListController extends GetxController {
  TaskListController({
    required this.engineService,
    required this.taskService,
    required this.desktopActions,
  });

  final EngineService engineService;
  final TaskService taskService;
  final DesktopActionsService desktopActions;
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final filter = TaskListFilter.all.obs;
  final sort = TaskListSort.newest.obs;
  final selectedTaskId = RxnString();
  final selectedTaskIds = <String>{}.obs;
  final batchMessage = RxnString();
  Worker? _engineWorker;
  bool _createDownloadOpen = false;

  List<DownloadTask> get tasks => taskService.tasks;
  List<DownloadTask> get visibleTasks {
    final query = searchQuery.value.trim().toLowerCase();
    final values = taskService.tasks.where((task) {
      if (!_matchesFilter(task, filter.value)) return false;
      if (query.isEmpty) return true;
      return task.fileName.toLowerCase().contains(query) ||
          task.url.toLowerCase().contains(query) ||
          task.saveDirectory.toLowerCase().contains(query);
    }).toList();
    values.sort(_taskComparator(sort.value));
    return values;
  }

  bool get hasSelection => selectedTaskIds.isNotEmpty;
  bool get allVisibleSelected {
    final ids = visibleTasks.map((task) => task.id).toSet();
    return ids.isNotEmpty && ids.every(selectedTaskIds.contains);
  }

  bool get anyVisibleSelected =>
      visibleTasks.any((task) => selectedTaskIds.contains(task.id));

  int countForFilter(TaskListFilter value) =>
      taskService.tasks.where((task) => _matchesFilter(task, value)).length;

  DownloadTask? get selectedTask {
    final id = selectedTaskId.value;
    return id == null ? null : taskService.taskById(id);
  }

  @override
  void onInit() {
    super.onInit();
    final initialFilter = Get.arguments;
    if (initialFilter is int &&
        initialFilter >= 0 &&
        initialFilter < TaskListFilter.values.length) {
      filter.value = TaskListFilter.values[initialFilter];
    }
    if (engineService.state.value == EngineConnectionState.online) {
      taskService.start();
    }
    _engineWorker = ever(engineService.state, (state) {
      if (state == EngineConnectionState.online) taskService.start();
    });
  }

  Future<void> retryEngine() => engineService.refresh();

  Future<void> retryTasks() => taskService.refresh();

  void updateSearch(String value) {
    if (searchQuery.value != value) {
      selectedTaskIds.clear();
      selectedTaskId.value = null;
    }
    searchQuery.value = value;
    batchMessage.value = null;
  }

  void setFilter(TaskListFilter value) {
    if (filter.value != value) {
      selectedTaskIds.clear();
      selectedTaskId.value = null;
    }
    filter.value = value;
    batchMessage.value = null;
  }

  void setSort(TaskListSort value) {
    sort.value = value;
  }

  Future<void> openCreateDownload() => _openCreateDownload();

  Future<void> pasteDownload() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    await _openCreateDownload(initialUrl: clipboard?.text?.trim() ?? '');
  }

  Future<void> _openCreateDownload({String initialUrl = ''}) async {
    if (_createDownloadOpen) return;
    _createDownloadOpen = true;
    try {
      await showCreateDownloadDialog(initialUrl: initialUrl);
    } finally {
      _createDownloadOpen = false;
    }
  }

  void openTask(DownloadTask task, {required bool compact}) {
    if (compact) {
      Get.toNamed<void>(Routes.taskDetailFor(task.id));
    } else {
      selectedTaskId.value = task.id;
    }
  }

  void toggleTaskSelection(String id) {
    if (!selectedTaskIds.remove(id)) selectedTaskIds.add(id);
    batchMessage.value = null;
  }

  void toggleSelectAllVisible() {
    final ids = visibleTasks.map((task) => task.id).toSet();
    if (ids.isEmpty) return;
    if (ids.every(selectedTaskIds.contains)) {
      selectedTaskIds.removeAll(ids);
    } else {
      selectedTaskIds.addAll(ids);
    }
    batchMessage.value = null;
  }

  void clearSelection() {
    selectedTaskIds.clear();
    batchMessage.value = null;
  }

  bool canBatch(BatchTaskAction action) =>
      _eligibleSelection(action).isNotEmpty;

  Future<void> performBatch(BatchTaskAction action) async {
    final ids = _eligibleSelection(action);
    if (ids.isEmpty) return;
    batchMessage.value = null;
    final result = await taskService.actOnTasks(ids, action);
    if (result == null) return;
    final succeededIds = result.items
        .where((item) => item.succeeded)
        .map((item) => item.id)
        .whereType<String>();
    selectedTaskIds.removeAll(succeededIds);
    if (result.failed > 0) {
      batchMessage.value = L10nKeys.tasksBatchPartial.trParams({
        'failed': '${result.failed}',
      });
    } else {
      batchMessage.value = L10nKeys.tasksBatchComplete.trParams({
        'count': '${result.succeeded}',
      });
    }
  }

  Future<void> pauseTask(DownloadTask task) => taskService.pause(task.id);

  Future<void> resumeTask(DownloadTask task) => taskService.resume(task.id);

  Future<void> cancelTask(DownloadTask task) => taskService.cancel(task.id);

  Future<void> openFile(DownloadTask task) => desktopActions.openFile(task);

  Future<void> revealFile(DownloadTask task) => desktopActions.revealFile(task);

  List<String> _eligibleSelection(BatchTaskAction action) {
    return selectedTaskIds
        .where((id) {
          final task = taskService.taskById(id);
          if (task == null || taskService.isActing(id)) return false;
          return switch (action) {
            BatchTaskAction.pause => task.canPause,
            BatchTaskAction.resume => task.canResume,
            BatchTaskAction.cancel => task.canCancel,
          };
        })
        .take(maxTaskBatchSize)
        .toList(growable: false);
  }

  bool _matchesFilter(DownloadTask task, TaskListFilter value) =>
      switch (value) {
        TaskListFilter.all => true,
        TaskListFilter.active =>
          task.state == DownloadTaskState.queued ||
              task.state == DownloadTaskState.downloading ||
              task.state == DownloadTaskState.retrying ||
              task.state == DownloadTaskState.paused,
        TaskListFilter.completed => task.state == DownloadTaskState.completed,
        TaskListFilter.issues => task.state == DownloadTaskState.failed,
      };

  Comparator<DownloadTask> _taskComparator(TaskListSort value) =>
      switch (value) {
        TaskListSort.newest => (left, right) {
          final order = right.createdAt.compareTo(left.createdAt);
          return order == 0 ? left.id.compareTo(right.id) : order;
        },
        TaskListSort.oldest => (left, right) {
          final order = left.createdAt.compareTo(right.createdAt);
          return order == 0 ? left.id.compareTo(right.id) : order;
        },
        TaskListSort.name => (left, right) {
          final order = left.fileName.toLowerCase().compareTo(
            right.fileName.toLowerCase(),
          );
          return order == 0 ? left.id.compareTo(right.id) : order;
        },
        TaskListSort.progress => (left, right) {
          final order = right.progress.compareTo(left.progress);
          return order == 0 ? right.createdAt.compareTo(left.createdAt) : order;
        },
        TaskListSort.size => (left, right) {
          final leftSize = left.total < 0 ? -1 : left.total;
          final rightSize = right.total < 0 ? -1 : right.total;
          final order = rightSize.compareTo(leftSize);
          return order == 0 ? right.createdAt.compareTo(left.createdAt) : order;
        },
      };

  @override
  void onClose() {
    _engineWorker?.dispose();
    searchController.dispose();
    super.onClose();
  }
}
