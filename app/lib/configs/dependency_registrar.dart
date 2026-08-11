import 'package:get/get.dart';

import '../data/clients/engine_client.dart';
import '../services/app_service.dart';
import '../services/directory_picker.dart';
import '../services/desktop_actions_service.dart';
import '../services/engine_service.dart';
import '../services/preferences_service.dart';
import '../services/task_service.dart';

class DependencyRegistrar {
  const DependencyRegistrar._();

  static void registerServices() {
    if (!Get.isRegistered<PreferencesService>()) {
      Get.put<PreferencesService>(PreferencesService(), permanent: true);
    }
    if (!Get.isRegistered<AppService>()) {
      Get.put<AppService>(AppService(), permanent: true);
    }
    if (!Get.isRegistered<EngineClient>()) {
      Get.put<EngineClient>(
        Get.isRegistered<EngineService>()
            ? Get.find<EngineService>().client
            : DioEngineClient(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<DirectoryPicker>()) {
      Get.put<DirectoryPicker>(const SystemDirectoryPicker(), permanent: true);
    }
    if (!Get.isRegistered<DesktopActionsService>()) {
      Get.put<DesktopActionsService>(
        DesktopActionsService(platform: const MethodChannelDesktopActions()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<EngineService>()) {
      Get.put<EngineService>(
        EngineService(client: Get.find<EngineClient>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<TaskService>()) {
      Get.put<TaskService>(
        TaskService(
          client: Get.find<EngineClient>(),
          desktopActions: Get.find<DesktopActionsService>(),
        ),
        permanent: true,
      );
    }
  }
}
