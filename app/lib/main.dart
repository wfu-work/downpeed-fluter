import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'configs/app_initializer.dart';
import 'configs/global_binding.dart';
import 'configs/localization/localization_service.dart';
import 'configs/theme/app_theme.dart';
import 'services/app_service.dart';

Future<void> main() async {
  await AppInitializer.init();
  runApp(
    DownpeedApp(
      initialThemeMode: AppService.to.themeMode.value,
      initialLocale: AppService.to.locale.value,
    ),
  );
}

class DownpeedApp extends StatelessWidget {
  const DownpeedApp({
    super.key,
    this.initialThemeMode = ThemeMode.system,
    this.initialLocale = LocalizationService.initialLocale,
    this.initialRoute = AppPages.initial,
  });

  final ThemeMode initialThemeMode;
  final Locale initialLocale;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Downpeed',
      debugShowCheckedModeBanner: false,
      initialBinding: GlobalBinding(),
      translations: LocalizationService(),
      locale: initialLocale,
      fallbackLocale: LocalizationService.fallbackLocale,
      scrollBehavior: const DownpeedScrollBehavior(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: initialThemeMode,
      initialRoute: initialRoute,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
    );
  }
}
