import 'package:get/get.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../domains/download_task.dart';
import '../../../services/desktop_actions_service.dart';
import '../../../services/bt_diagnostics_service.dart';
import '../../../services/task_service.dart';
import '../../widgets/delete_task_dialog.dart';

class TaskDetailController extends GetxController {
  TaskDetailController({
    required this.taskService,
    required this.btDiagnostics,
    required this.desktopActions,
    required this.taskId,
  });

  final TaskService taskService;
  final BTDiagnosticsService btDiagnostics;
  final DesktopActionsService desktopActions;
  final String taskId;
  final deleteErrorMessage = RxnString();
  final diagnosticsExpanded = false.obs;

  DownloadTask? get task => taskService.taskById(taskId);

  @override
  void onReady() {
    super.onReady();
    taskService.start();
    if (taskId.isNotEmpty) taskService.loadTask(taskId);
  }

  Future<void> pause() => taskService.pause(taskId);

  Future<void> resume() => taskService.resume(taskId);

  Future<void> retry() => taskService.retry(taskId);

  Future<void> cancel() => taskService.cancel(taskId);

  Future<void> toggleDiagnostics() async {
    final expanded = !diagnosticsExpanded.value;
    diagnosticsExpanded.value = expanded;
    await btDiagnostics.setExpanded(taskId, expanded);
  }

  Future<void> delete() async {
    final value = task;
    if (value == null || !value.isTerminal || taskService.isActing(taskId)) {
      return;
    }
    final deleteFile = await showDeleteTaskDialog(
      taskCount: 1,
      allowDeleteFiles: value.state == DownloadTaskState.completed,
    );
    if (deleteFile == null) return;
    deleteErrorMessage.value = null;
    final result = await taskService.deleteTask(taskId, deleteFile: deleteFile);
    if (result != null) {
      Get.back<void>();
    } else {
      deleteErrorMessage.value = L10nKeys.tasksDeleteError.tr;
    }
  }

  Future<void> openFile() async {
    final value = task;
    if (value != null) await desktopActions.openFile(value);
  }

  Future<void> revealFile() async {
    final value = task;
    if (value != null) await desktopActions.revealFile(value);
  }

  void back() => Get.back<void>();

  @override
  void onClose() {
    btDiagnostics.setExpanded(taskId, false);
    super.onClose();
  }
}
