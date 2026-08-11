import 'package:get/get.dart';

import '../../../domains/download_task.dart';
import '../../../services/desktop_actions_service.dart';
import '../../../services/task_service.dart';

class TaskDetailController extends GetxController {
  TaskDetailController({
    required this.taskService,
    required this.desktopActions,
    required this.taskId,
  });

  final TaskService taskService;
  final DesktopActionsService desktopActions;
  final String taskId;

  DownloadTask? get task => taskService.taskById(taskId);

  @override
  void onReady() {
    super.onReady();
    taskService.start();
    if (taskId.isNotEmpty) taskService.loadTask(taskId);
  }

  Future<void> pause() => taskService.pause(taskId);

  Future<void> resume() => taskService.resume(taskId);

  Future<void> cancel() => taskService.cancel(taskId);

  Future<void> openFile() async {
    final value = task;
    if (value != null) await desktopActions.openFile(value);
  }

  Future<void> revealFile() async {
    final value = task;
    if (value != null) await desktopActions.revealFile(value);
  }

  void back() => Get.back<void>();
}
