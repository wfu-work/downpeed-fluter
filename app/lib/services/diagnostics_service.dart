import 'package:get/get.dart';

import '../configs/localization/l10n_keys.dart';
import '../data/clients/engine_client.dart';
import '../domains/engine_diagnostics.dart';
import 'desktop_actions_service.dart';
import 'diagnostic_archive_saver.dart';

class DiagnosticsService extends GetxService {
  DiagnosticsService({
    required this.client,
    required this.archiveSaver,
    required this.desktopActions,
  });

  static DiagnosticsService get to => Get.find<DiagnosticsService>();

  final EngineClient client;
  final DiagnosticArchiveSaver archiveSaver;
  final DesktopActionsPlatform desktopActions;
  final diagnostics = Rxn<EngineDiagnostics>();
  final isLoading = false.obs;
  final isExporting = false.obs;
  final loadErrorMessage = RxnString();
  final exportErrorMessage = RxnString();
  final savedArchivePath = RxnString();

  bool get canRevealSavedArchive =>
      desktopActions.isSupported &&
      (savedArchivePath.value?.trim().isNotEmpty ?? false);

  Future<void> load({bool force = false}) async {
    if (isLoading.value || (!force && diagnostics.value != null)) return;
    isLoading.value = true;
    loadErrorMessage.value = null;
    try {
      diagnostics.value = await client.fetchDiagnostics();
    } on EngineClientException catch (error) {
      loadErrorMessage.value = error.code == 'engine_unreachable'
          ? L10nKeys.settingsDiagnosticsOffline.tr
          : L10nKeys.settingsDiagnosticsLoadError.tr;
    } on Object {
      loadErrorMessage.value = L10nKeys.settingsDiagnosticsLoadError.tr;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportArchive() async {
    if (isExporting.value) return;
    isExporting.value = true;
    exportErrorMessage.value = null;
    try {
      final archive = await client.exportDiagnostics();
      final path = await archiveSaver.save(archive);
      if (path == null || path.trim().isEmpty) return;
      savedArchivePath.value = path.trim();
    } on EngineClientException catch (error) {
      exportErrorMessage.value = error.code == 'engine_unreachable'
          ? L10nKeys.settingsDiagnosticsOffline.tr
          : L10nKeys.settingsDiagnosticsExportError.tr;
    } on Object {
      exportErrorMessage.value = L10nKeys.settingsDiagnosticsSaveError.tr;
    } finally {
      isExporting.value = false;
    }
  }

  Future<void> revealSavedArchive() async {
    final path = savedArchivePath.value;
    if (!desktopActions.isSupported || path == null || path.trim().isEmpty) {
      return;
    }
    exportErrorMessage.value = null;
    try {
      await desktopActions.revealFile(path);
    } on Object {
      exportErrorMessage.value = L10nKeys.settingsDiagnosticsRevealError.tr;
    }
  }
}
