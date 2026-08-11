import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/app_service.dart';
import '../../../services/engine_service.dart';
import '../../../services/preferences_service.dart';
import '../../routes/app_pages.dart';
import '../task_list/task_list_controller.dart';

class SettingsController extends GetxController {
  SettingsController({
    required this.appService,
    required this.preferences,
    required this.engineService,
  });

  final AppService appService;
  final PreferencesService preferences;
  final EngineService engineService;

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

  Future<void> refreshEngine() => engineService.refresh();

  void openTaskFilter(int index) {
    if (index < 0 || index >= TaskListFilter.values.length) return;
    if (Get.isRegistered<TaskListController>()) {
      Get.find<TaskListController>().setFilter(TaskListFilter.values[index]);
    }
    if (Get.currentRoute.split('?').first == Routes.tasks) return;
    Get.until((route) => route.settings.name == Routes.tasks || route.isFirst);
    if (Get.currentRoute.split('?').first != Routes.tasks) {
      Get.offAllNamed<void>(Routes.tasks, arguments: index);
    }
  }
}
