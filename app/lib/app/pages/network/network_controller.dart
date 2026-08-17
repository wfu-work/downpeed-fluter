import 'dart:async';

import 'package:get/get.dart';

import '../../../domains/engine_info.dart';
import '../../../services/engine_service.dart';
import '../../../services/engine_settings_service.dart';
import '../../routes/app_pages.dart';

class NetworkController extends GetxController {
  NetworkController({
    required this.engineService,
    required this.settingsService,
  });

  final EngineService engineService;
  final EngineSettingsService settingsService;
  Worker? _engineWorker;

  @override
  void onInit() {
    super.onInit();
    if (engineService.state.value == EngineConnectionState.online) {
      _scheduleSettingsLoad();
    }
    _engineWorker = ever(engineService.state, (state) {
      if (state == EngineConnectionState.online) {
        _scheduleSettingsLoad();
      }
    });
  }

  void _scheduleSettingsLoad() {
    scheduleMicrotask(() => unawaited(settingsService.load()));
  }

  @override
  Future<void> refresh() async {
    await engineService.refresh();
    if (engineService.state.value == EngineConnectionState.online) {
      await settingsService.load(force: true);
    }
  }

  void openSettings() => Get.offAllNamed<void>(Routes.settings);

  @override
  void onClose() {
    _engineWorker?.dispose();
    super.onClose();
  }
}
