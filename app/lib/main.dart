import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'configs/app_initializer.dart';
import 'configs/global_binding.dart';
import 'configs/localization/localization_service.dart';
import 'configs/theme/app_theme.dart';
import 'services/app_command_service.dart';
import 'services/app_service.dart';

Future<void> main(List<String> arguments) async {
  await AppInitializer.init(launchArguments: arguments);
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
      builder: (context, child) =>
          _ApplicationCommandScope(child: child ?? const SizedBox.shrink()),
    );
  }
}

class _ApplicationCommandScope extends StatefulWidget {
  const _ApplicationCommandScope({required this.child});

  final Widget child;

  @override
  State<_ApplicationCommandScope> createState() =>
      _ApplicationCommandScopeState();
}

class _ApplicationCommandScopeState extends State<_ApplicationCommandScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<AppCommandService>()) {
        unawaited(AppCommandService.to.markNavigationReady());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    void run(Future<void> Function() command) => unawaited(command());

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            run(AppCommandService.to.openNewDownload),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            run(AppCommandService.to.openNewDownload),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            run(AppCommandService.to.focusTaskSearch),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            run(AppCommandService.to.focusTaskSearch),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
            run(AppCommandService.to.openSettings),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            run(AppCommandService.to.openSettings),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            run(AppCommandService.to.refreshCurrent),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            run(AppCommandService.to.refreshCurrent),
      },
      child: Focus(autofocus: true, child: widget.child),
    );
  }
}
