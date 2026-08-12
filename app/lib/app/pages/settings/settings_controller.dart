import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../configs/build_info.dart';
import '../../../services/app_service.dart';
import '../../../services/engine_service.dart';
import '../../../services/preferences_service.dart';
import '../../routes/app_pages.dart';

enum SettingsSection { appearance, workspace, notifications, engine, about }

class SettingsController extends GetxController {
  SettingsController({
    required this.appService,
    required this.preferences,
    required this.engineService,
  });

  final AppService appService;
  final PreferencesService preferences;
  final EngineService engineService;
  final selectedSection = SettingsSection.appearance.obs;
  final compactDetailVisible = false.obs;

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

  void openLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Downpeed',
      applicationVersion: DownpeedBuildInfo.displayVersion,
    );
  }

  Future<void> refreshEngine() => engineService.refresh();
}
