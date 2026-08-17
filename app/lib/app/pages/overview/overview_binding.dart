import 'package:get/get.dart';

import '../../../services/engine_service.dart';
import '../../../services/task_service.dart';
import 'overview_controller.dart';

class OverviewBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<OverviewController>()) {
      Get.lazyPut<OverviewController>(
        () => OverviewController(
          engineService: EngineService.to,
          taskService: TaskService.to,
        ),
      );
    }
  }
}
