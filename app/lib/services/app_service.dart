import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'desktop_integration_service.dart';
import 'preferences_service.dart';

class AppService extends GetxService {
  static AppService get to => Get.find<AppService>();

  final themeMode = ThemeMode.system.obs;
  final locale = const Locale('zh', 'CN').obs;

  Future<void> restore() async {
    final themeModeIndex = PreferencesService.to.themeModeIndex;
    if (themeModeIndex != null &&
        themeModeIndex >= 0 &&
        themeModeIndex < ThemeMode.values.length) {
      themeMode.value = ThemeMode.values[themeModeIndex];
    }
    locale.value = switch (PreferencesService.to.localeCode) {
      'en_US' => const Locale('en', 'US'),
      _ => const Locale('zh', 'CN'),
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    await PreferencesService.to.saveThemeModeIndex(mode.index);
  }

  Future<void> setLocale(Locale value) async {
    locale.value = value;
    await Get.updateLocale(value);
    await PreferencesService.to.saveLocaleCode(
      value.languageCode == 'en' ? 'en_US' : 'zh_CN',
    );
    if (Get.isRegistered<DesktopIntegrationService>()) {
      await DesktopIntegrationService.to.refreshLocalizedMenu();
    }
  }
}
