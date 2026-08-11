import 'package:get/get.dart';

import '../../../services/app_service.dart';
import '../../../services/engine_service.dart';
import '../../../services/preferences_service.dart';
import 'settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SettingsController>()) {
      Get.lazyPut<SettingsController>(
        () => SettingsController(
          appService: AppService.to,
          preferences: PreferencesService.to,
          engineService: EngineService.to,
        ),
      );
    }
  }
}
