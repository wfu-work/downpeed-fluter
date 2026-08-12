import 'package:get/get.dart';

import '../../../services/task_service.dart';
import '../../../services/bt_diagnostics_service.dart';
import '../../../services/desktop_actions_service.dart';
import 'task_detail_controller.dart';

class TaskDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TaskDetailController>(
      () => TaskDetailController(
        taskService: TaskService.to,
        btDiagnostics: Get.find<BTDiagnosticsService>(),
        desktopActions: DesktopActionsService.to,
        taskId: Get.parameters['id'] ?? '',
      ),
    );
  }
}
