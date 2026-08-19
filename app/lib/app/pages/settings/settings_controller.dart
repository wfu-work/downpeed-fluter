import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../configs/build_info.dart';
import '../../../configs/localization/l10n_keys.dart';
import '../../../domains/engine_settings.dart';
import '../../../domains/engine_info.dart';
import '../../../services/app_service.dart';
import '../../../services/directory_picker.dart';
import '../../../services/diagnostics_service.dart';
import '../../../services/engine_service.dart';
import '../../../services/engine_settings_service.dart';
import '../../../services/preferences_service.dart';
import '../../../services/proxy_settings_service.dart';
import '../../../services/startup_service.dart';
import '../../routes/app_pages.dart';

enum SettingsSection {
  appearance,
  workspace,
  notifications,
  downloads,
  scheduler,
  connection,
  bitTorrent,
  engine,
  diagnostics,
  about,
}

class SettingsController extends GetxController {
  SettingsController({
    required this.appService,
    required this.preferences,
    required this.engineService,
    required this.engineSettingsService,
    required this.directoryPicker,
    required this.diagnosticsService,
    required this.startupService,
    required this.proxySettingsService,
  });

  final AppService appService;
  final PreferencesService preferences;
  final EngineService engineService;
  final EngineSettingsService engineSettingsService;
  final DirectoryPicker directoryPicker;
  final DiagnosticsService diagnosticsService;
  final StartupService startupService;
  final ProxySettingsService proxySettingsService;
  final selectedSection = SettingsSection.appearance.obs;
  final compactDetailVisible = false.obs;
  final isPickingDownloadDirectory = false.obs;
  final proxyMode = ProxyMode.direct.obs;
  final proxyConnectTimeoutSeconds = 10.obs;
  final proxyResponseTimeoutSeconds = 30.obs;
  final proxyHostController = TextEditingController();
  final proxyPortController = TextEditingController();
  final proxyUsernameController = TextEditingController();
  final proxyPasswordController = TextEditingController();

  void selectSection(SettingsSection section, {required bool compact}) {
    selectedSection.value = section;
    if (section == SettingsSection.diagnostics) {
      unawaited(diagnosticsService.load());
    }
    if (section == SettingsSection.connection) {
      syncProxyDraft();
    }
    if (compact) compactDetailVisible.value = true;
  }

  void closeCompactDetail() {
    compactDetailVisible.value = false;
  }

  void backToTasks() {
    final navigator = Get.key.currentState;
    if (navigator?.canPop() ?? false) {
      Get.back<void>();
      return;
    }
    Get.offAllNamed<void>(Routes.tasks);
  }

  void selectTheme(Set<ThemeMode> selection) {
    if (selection.isEmpty) return;
    unawaited(appService.setThemeMode(selection.first));
  }

  void selectLanguage(Set<String> selection) {
    if (selection.isEmpty) return;
    final locale = selection.first == 'en'
        ? const Locale('en', 'US')
        : const Locale('zh', 'CN');
    unawaited(appService.setLocale(locale));
  }

  void setSidebarExpanded(bool value) {
    unawaited(preferences.setSidebarExpanded(value));
  }

  void resetSidebarWidth() {
    unawaited(preferences.resetSidebarWidth());
  }

  void setCompletionNotificationsEnabled(bool value) {
    unawaited(preferences.setCompletionNotificationsEnabled(value));
  }

  void setDownloadCompletionAction(DownloadCompletionAction value) {
    unawaited(preferences.setDownloadCompletionAction(value));
  }

  void setCloseToTrayEnabled(bool value) {
    unawaited(preferences.setCloseToTrayEnabled(value));
  }

  Future<void> setLaunchAtLogin(bool value) => startupService.setEnabled(value);

  void setStartHiddenOnLogin(bool value) {
    unawaited(preferences.setStartHiddenOnLogin(value));
  }

  void openLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Downpeed',
      applicationVersion: DownpeedBuildInfo.displayVersion,
    );
  }

  Future<void> refreshEngine() => engineService.refresh();

  Future<void> refreshDiagnostics() => diagnosticsService.load(force: true);

  Future<void> refreshCurrent() async {
    await engineService.refresh();
    if (engineService.state.value == EngineConnectionState.online) {
      await engineSettingsService.load(force: true);
      syncProxyDraft();
    }
    if (selectedSection.value == SettingsSection.diagnostics) {
      await diagnosticsService.load(force: true);
    }
  }

  Future<void> exportDiagnostics() => diagnosticsService.exportArchive();

  Future<void> revealDiagnosticArchive() =>
      diagnosticsService.revealSavedArchive();

  Future<void> chooseDefaultDownloadDirectory() async {
    if (isPickingDownloadDirectory.value ||
        engineSettingsService.isSaving.value) {
      return;
    }
    isPickingDownloadDirectory.value = true;
    engineSettingsService.errorMessage.value = null;
    try {
      final selected = await directoryPicker.chooseDirectory(
        initialDirectory: engineSettingsService.defaultDownloadDirectory,
      );
      if (selected == null || selected.trim().isEmpty) return;
      await engineSettingsService.updateDefaultDownloadDirectory(
        selected.trim(),
      );
    } on Object {
      engineSettingsService.errorMessage.value =
          L10nKeys.settingsDownloadDirectoryPickerError.tr;
    } finally {
      isPickingDownloadDirectory.value = false;
    }
  }

  Future<void> selectBTPeerConnections(int value) =>
      engineSettingsService.updateBTPeerConnections(value);

  Future<void> setFileConflictPolicy(FileConflictPolicy policy) =>
      engineSettingsService.updateFileConflictPolicy(policy);

  Future<void> setMaxConcurrentTasks(int value) async {
    final scheduler = engineSettingsService.scheduler;
    if (scheduler == null) return;
    await engineSettingsService.updateSchedulerSettings(
      scheduler.copyWith(maxConcurrentTasks: value),
    );
  }

  Future<void> setDownloadRateLimit(int value) async {
    final scheduler = engineSettingsService.scheduler;
    if (scheduler == null) return;
    await engineSettingsService.updateSchedulerSettings(
      scheduler.copyWith(downloadRateLimit: value),
    );
  }

  Future<void> setMaxRetries(int value) async {
    final scheduler = engineSettingsService.scheduler;
    if (scheduler == null) return;
    await engineSettingsService.updateSchedulerSettings(
      scheduler.copyWith(maxRetries: value),
    );
  }

  void selectProxyMode(ProxyMode value) {
    proxyMode.value = value;
  }

  void setProxyConnectTimeout(int value) {
    proxyConnectTimeoutSeconds.value = value;
  }

  void setProxyResponseTimeout(int value) {
    proxyResponseTimeoutSeconds.value = value;
  }

  void syncProxyDraft() {
    final settings = engineSettingsService.proxy;
    if (settings == null) return;
    proxyMode.value = settings.mode;
    proxyHostController.text = settings.host;
    proxyPortController.text = settings.port == 0 ? '' : '${settings.port}';
    proxyUsernameController.text = settings.username;
    proxyPasswordController.clear();
    proxyConnectTimeoutSeconds.value = settings.connectTimeoutSeconds;
    proxyResponseTimeoutSeconds.value = settings.responseHeaderTimeoutSeconds;
  }

  Future<void> saveProxySettings() async {
    final current = engineSettingsService.proxy;
    if (current == null) return;
    final mode = proxyMode.value;
    final port = int.tryParse(proxyPortController.text.trim()) ?? 0;
    if (mode.isManual &&
        (proxyHostController.text.trim().isEmpty || port < 1 || port > 65535)) {
      proxySettingsService.errorMessage.value =
          L10nKeys.settingsProxyInvalid.tr;
      return;
    }
    final replacement = proxyPasswordController.text.isEmpty
        ? null
        : proxyPasswordController.text;
    final saved = await proxySettingsService.save(
      ProxySettings(
        mode: mode,
        host: proxyHostController.text.trim(),
        port: port,
        username: proxyUsernameController.text.trim(),
        connectTimeoutSeconds: proxyConnectTimeoutSeconds.value,
        responseHeaderTimeoutSeconds: proxyResponseTimeoutSeconds.value,
      ),
      replacementPassword: replacement,
    );
    if (saved) syncProxyDraft();
  }

  Future<void> clearProxyCredential() async {
    if (await proxySettingsService.clearCredential()) {
      proxyPasswordController.clear();
    }
  }

  Future<void> testProxy() => proxySettingsService.test();

  @override
  void onInit() {
    super.onInit();
    unawaited(startupService.initialize());
    unawaited(_initializeEngineSettings());
  }

  Future<void> _initializeEngineSettings() async {
    await engineSettingsService.load();
    syncProxyDraft();
    await proxySettingsService.initialize();
  }

  @override
  void onClose() {
    proxyHostController.dispose();
    proxyPortController.dispose();
    proxyUsernameController.dispose();
    proxyPasswordController.dispose();
    super.onClose();
  }
}
