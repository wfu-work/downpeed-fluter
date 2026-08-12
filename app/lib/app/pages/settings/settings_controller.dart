import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../configs/build_info.dart';
import '../../../configs/localization/l10n_keys.dart';
import '../../../services/app_service.dart';
import '../../../services/directory_picker.dart';
import '../../../services/engine_service.dart';
import '../../../services/engine_settings_service.dart';
import '../../../services/preferences_service.dart';
import '../../../services/startup_service.dart';
import '../../routes/app_pages.dart';

enum SettingsSection {
  appearance,
  workspace,
  notifications,
  downloads,
  bitTorrent,
  engine,
  about,
}

class SettingsController extends GetxController {
  SettingsController({
    required this.appService,
    required this.preferences,
    required this.engineService,
    required this.engineSettingsService,
    required this.directoryPicker,
    required this.startupService,
  });

  final AppService appService;
  final PreferencesService preferences;
  final EngineService engineService;
  final EngineSettingsService engineSettingsService;
  final DirectoryPicker directoryPicker;
  final StartupService startupService;
  final selectedSection = SettingsSection.appearance.obs;
  final compactDetailVisible = false.obs;
  final isPickingDownloadDirectory = false.obs;

  void selectSection(SettingsSection section, {required bool compact}) {
    selectedSection.value = section;
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

  @override
  void onInit() {
    super.onInit();
    unawaited(startupService.initialize());
    unawaited(engineSettingsService.load());
  }
}
