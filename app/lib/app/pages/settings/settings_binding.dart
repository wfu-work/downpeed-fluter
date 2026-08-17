import 'package:get/get.dart';

import '../../../services/app_service.dart';
import '../../../services/engine_service.dart';
import '../../../services/engine_settings_service.dart';
import '../../../services/directory_picker.dart';
import '../../../services/diagnostics_service.dart';
import '../../../services/preferences_service.dart';
import '../../../services/startup_service.dart';
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
          engineSettingsService: EngineSettingsService.to,
          directoryPicker: Get.find<DirectoryPicker>(),
          diagnosticsService: DiagnosticsService.to,
          startupService: StartupService.to,
        ),
      );
    }
  }
}
