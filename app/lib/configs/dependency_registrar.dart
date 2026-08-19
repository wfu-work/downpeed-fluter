import 'package:get/get.dart';

import '../data/clients/engine_client.dart';
import '../services/app_command_service.dart';
import '../services/app_link_service.dart';
import '../services/app_service.dart';
import '../services/bt_diagnostics_service.dart';
import '../services/directory_picker.dart';
import '../services/diagnostic_archive_saver.dart';
import '../services/diagnostics_service.dart';
import '../services/desktop_actions_service.dart';
import '../services/desktop_integration_service.dart';
import '../services/download_dialog_service.dart';
import '../services/embedded_engine_service.dart';
import '../services/engine_service.dart';
import '../services/engine_settings_service.dart';
import '../services/preferences_service.dart';
import '../services/proxy_credential_store.dart';
import '../services/proxy_settings_service.dart';
import '../services/startup_service.dart';
import '../services/task_service.dart';
import '../services/torrent_file_picker.dart';

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
    if (!Get.isRegistered<EmbeddedEngineService>()) {
      Get.put<EmbeddedEngineService>(
        EmbeddedEngineService(probeClient: Get.find<EngineClient>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<DesktopIntegrationService>()) {
      Get.put<DesktopIntegrationService>(
        DesktopIntegrationService(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<DownloadDialogService>()) {
      Get.put<DownloadDialogService>(DownloadDialogService(), permanent: true);
    }
    if (!Get.isRegistered<AppCommandService>()) {
      Get.put<AppCommandService>(
        AppCommandService(showWindow: DesktopIntegrationService.to.showWindow),
        permanent: true,
      );
    }
    if (!Get.isRegistered<AppLinkService>()) {
      Get.put<AppLinkService>(AppLinkService(), permanent: true);
    }
    if (!Get.isRegistered<StartupService>()) {
      Get.put<StartupService>(StartupService(), permanent: true);
    }
    if (!Get.isRegistered<DirectoryPicker>()) {
      Get.put<DirectoryPicker>(const SystemDirectoryPicker(), permanent: true);
    }
    if (!Get.isRegistered<DiagnosticArchiveSaver>()) {
      Get.put<DiagnosticArchiveSaver>(
        const SystemDiagnosticArchiveSaver(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<TorrentFilePicker>()) {
      Get.put<TorrentFilePicker>(
        const SystemTorrentFilePicker(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<DesktopActionsService>()) {
      Get.put<DesktopActionsService>(
        DesktopActionsService(
          platform: const MethodChannelDesktopActions(),
          completionNotificationsEnabled: () =>
              PreferencesService.to.completionNotificationsEnabled.value,
          revealCompletedFileEnabled: () =>
              PreferencesService.to.downloadCompletionAction.value ==
              DownloadCompletionAction.revealFile,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<EngineService>()) {
      Get.put<EngineService>(
        EngineService(client: Get.find<EngineClient>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<EngineSettingsService>()) {
      Get.put<EngineSettingsService>(
        EngineSettingsService(client: Get.find<EngineClient>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ProxyCredentialStore>()) {
      Get.put<ProxyCredentialStore>(
        const MethodChannelProxyCredentialStore(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ProxySettingsService>()) {
      Get.put<ProxySettingsService>(
        ProxySettingsService(
          client: Get.find<EngineClient>(),
          engineSettings: EngineSettingsService.to,
          credentialStore: Get.find<ProxyCredentialStore>(),
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<DiagnosticsService>()) {
      Get.put<DiagnosticsService>(
        DiagnosticsService(
          client: Get.find<EngineClient>(),
          archiveSaver: Get.find<DiagnosticArchiveSaver>(),
          desktopActions: Get.find<DesktopActionsService>().platform,
        ),
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
    if (!Get.isRegistered<BTDiagnosticsService>()) {
      Get.put<BTDiagnosticsService>(
        BTDiagnosticsService(client: Get.find<EngineClient>()),
        permanent: true,
      );
    }
  }
}
