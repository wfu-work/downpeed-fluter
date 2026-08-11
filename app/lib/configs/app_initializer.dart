import 'package:flutter/widgets.dart';

import '../services/app_service.dart';
import '../services/engine_service.dart';
import '../services/preferences_service.dart';
import 'dependency_registrar.dart';

class AppInitializer {
  const AppInitializer._();

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    DependencyRegistrar.registerServices();
    await PreferencesService.to.init();
    await AppService.to.restore();
    await EngineService.to.refresh();
  }
}
