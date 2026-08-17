import 'package:get/get.dart';

import '../../../services/engine_service.dart';
import '../../../services/engine_settings_service.dart';
import 'network_controller.dart';

class NetworkBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<NetworkController>()) {
      Get.lazyPut<NetworkController>(
        () => NetworkController(
          engineService: EngineService.to,
          settingsService: EngineSettingsService.to,
        ),
      );
    }
  }
}
