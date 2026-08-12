import 'package:flutter/widgets.dart';

import '../domains/engine_info.dart';
import '../services/app_service.dart';
import '../services/desktop_integration_service.dart';
import '../services/embedded_engine_service.dart';
import '../services/engine_service.dart';
import '../services/engine_settings_service.dart';
import '../services/preferences_service.dart';
import '../services/startup_service.dart';
import 'dependency_registrar.dart';

class AppInitializer {
  const AppInitializer._();

  static Future<void> init({List<String> launchArguments = const []}) async {
    WidgetsFlutterBinding.ensureInitialized();
    DependencyRegistrar.registerServices();
    await PreferencesService.to.init();
    await StartupService.to.initialize();
    await AppService.to.restore();
    await EmbeddedEngineService.to.initialize();
    await DesktopIntegrationService.to.initialize(
      launchArguments: launchArguments,
    );
    await EngineService.to.refresh();
    if (EngineService.to.state.value == EngineConnectionState.online) {
      await EngineSettingsService.to.load();
    }
  }
}
