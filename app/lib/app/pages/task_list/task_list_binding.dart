import 'package:get/get.dart';

import '../../../services/engine_service.dart';
import '../../../services/desktop_actions_service.dart';
import '../../../services/task_service.dart';
import 'task_list_controller.dart';

class TaskListBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TaskListController>()) {
      Get.lazyPut<TaskListController>(
        () => TaskListController(
          engineService: EngineService.to,
          taskService: TaskService.to,
          desktopActions: DesktopActionsService.to,
        ),
      );
    }
  }
}
