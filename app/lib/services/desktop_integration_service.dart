import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'app_command_service.dart';
import 'embedded_engine_service.dart';
import 'preferences_service.dart';

const downpeedStartupLaunchArgument = '--downpeed-startup';

enum DesktopTrayCommand { showWindow, newDownload, quit }

class DesktopTrayLabels {
  const DesktopTrayLabels({
    required this.showWindow,
    required this.newDownload,
    required this.quit,
  });

  final String showWindow;
  final String newDownload;
  final String quit;
}

abstract interface class DesktopWindowHost {
  Future<void> initialize({required Future<void> Function() onClose});

  Future<void> setPreventClose(bool value);

  Future<void> hide();

  Future<void> show();

  Future<void> focus();

  Future<void> destroy();

  void dispose();
}

abstract interface class DesktopTrayHost {
  Future<void> initialize({
    required DesktopTrayLabels labels,
    required Future<void> Function() onActivate,
    required Future<void> Function(DesktopTrayCommand command) onCommand,
  });

  Future<void> updateMenu(DesktopTrayLabels labels);

  Future<void> destroy();
}

class DesktopIntegrationService extends GetxService {
  DesktopIntegrationService({
    DesktopWindowHost? windowHost,
    DesktopTrayHost? trayHost,
    Future<void> Function()? shutdownEngine,
    Future<void> Function()? openNewDownload,
    bool Function()? closeToTrayEnabled,
    bool Function()? startHiddenOnLogin,
    bool? desktopSupported,
  }) : _windowHost = windowHost ?? WindowManagerDesktopWindowHost(),
       _trayHost = trayHost ?? SystemDesktopTrayHost(),
       _shutdownEngineOverride = shutdownEngine,
       _openNewDownloadOverride = openNewDownload,
       _closeToTrayEnabledOverride = closeToTrayEnabled,
       _startHiddenOnLoginOverride = startHiddenOnLogin,
       _desktopSupported = desktopSupported ?? _isDesktopPlatform;

  static DesktopIntegrationService get to =>
      Get.find<DesktopIntegrationService>();

  final DesktopWindowHost _windowHost;
  final DesktopTrayHost _trayHost;
  final Future<void> Function()? _shutdownEngineOverride;
  final Future<void> Function()? _openNewDownloadOverride;
  final bool Function()? _closeToTrayEnabledOverride;
  final bool Function()? _startHiddenOnLoginOverride;
  final bool _desktopSupported;

  final windowReady = false.obs;
  final trayAvailable = false.obs;
  final isQuitting = false.obs;
  final errorMessage = RxnString();

  Future<void>? _initializing;
  bool _disposed = false;

  bool get isSupported => _desktopSupported;

  Future<void> initialize({List<String> launchArguments = const []}) =>
      _initializing ??= _initialize(
        launchArguments,
      ).whenComplete(() => _initializing = null);

  Future<void> _initialize(List<String> launchArguments) async {
    if (!_desktopSupported || _disposed) return;
    final launchedAtLogin = launchArguments.contains(
      downpeedStartupLaunchArgument,
    );
    errorMessage.value = null;

    try {
      await _windowHost.initialize(onClose: handleCloseRequested);
      await _windowHost.setPreventClose(true);
      windowReady.value = true;
    } on Object {
      errorMessage.value =
          'Downpeed could not initialize desktop window controls.';
      if (launchedAtLogin) {
        try {
          await _windowHost.show();
          await _windowHost.focus();
        } on Object {
          // The window initialization failure remains the actionable error.
        }
      }
      return;
    }

    try {
      await _trayHost.initialize(
        labels: _localizedLabels(),
        onActivate: showWindow,
        onCommand: handleTrayCommand,
      );
      trayAvailable.value = true;
    } on Object {
      trayAvailable.value = false;
      errorMessage.value = 'The system tray is unavailable on this desktop.';
    }

    if (!launchedAtLogin) return;
    if (trayAvailable.value && _shouldStartHiddenOnLogin) {
      try {
        await _windowHost.hide();
        return;
      } on Object {
        trayAvailable.value = false;
        errorMessage.value = 'The window could not start in the system tray.';
      }
    }
    await showWindow();
  }

  Future<void> refreshLocalizedMenu() async {
    if (!trayAvailable.value || _disposed) return;
    try {
      await _trayHost.updateMenu(_localizedLabels());
    } on Object {
      trayAvailable.value = false;
      errorMessage.value = 'The system tray menu could not be updated.';
    }
  }

  Future<void> handleCloseRequested() async {
    if (isQuitting.value || _disposed) return;
    if (trayAvailable.value && _shouldCloseToTray) {
      try {
        await _windowHost.hide();
        return;
      } on Object {
        trayAvailable.value = false;
        errorMessage.value = 'The window could not be hidden to the tray.';
      }
    }
    await quit();
  }

  Future<void> handleTrayCommand(DesktopTrayCommand command) async {
    switch (command) {
      case DesktopTrayCommand.showWindow:
        await showWindow();
      case DesktopTrayCommand.newDownload:
        await showWindow();
        await (_openNewDownloadOverride ?? _showNewDownload)();
      case DesktopTrayCommand.quit:
        await quit();
    }
  }

  Future<void> showWindow() async {
    if (!windowReady.value || _disposed) return;
    try {
      await _windowHost.show();
      await _windowHost.focus();
      errorMessage.value = null;
    } on Object {
      errorMessage.value = 'The Downpeed window could not be restored.';
    }
  }

  Future<void> quit() async {
    if (isQuitting.value || _disposed) return;
    isQuitting.value = true;
    errorMessage.value = null;
    try {
      if (windowReady.value) await _windowHost.setPreventClose(false);
      if (trayAvailable.value) await _trayHost.destroy();
      trayAvailable.value = false;
      await (_shutdownEngineOverride ?? _stopEmbeddedEngine)();
      if (windowReady.value) await _windowHost.destroy();
    } on Object {
      errorMessage.value = 'Downpeed could not exit cleanly.';
      isQuitting.value = false;
      if (windowReady.value) {
        try {
          await _windowHost.setPreventClose(true);
        } on Object {
          // The original error remains the actionable failure.
        }
      }
    }
  }

  bool get _shouldCloseToTray =>
      _closeToTrayEnabledOverride?.call() ??
      (Get.isRegistered<PreferencesService>()
          ? PreferencesService.to.closeToTrayEnabled.value
          : true);

  bool get _shouldStartHiddenOnLogin =>
      _startHiddenOnLoginOverride?.call() ??
      (Get.isRegistered<PreferencesService>()
          ? PreferencesService.to.startHiddenOnLogin.value
          : false);

  Future<void> _stopEmbeddedEngine() async {
    if (Get.isRegistered<EmbeddedEngineService>()) {
      await EmbeddedEngineService.to.shutdown();
    }
  }

  Future<void> _showNewDownload() async {
    await AppCommandService.to.openNewDownload();
  }

  DesktopTrayLabels _localizedLabels() {
    final english =
        Get.locale?.languageCode == 'en' ||
        (Get.locale == null &&
            Get.isRegistered<PreferencesService>() &&
            PreferencesService.to.localeCode == 'en_US');
    return DesktopTrayLabels(
      showWindow: english ? 'Show Downpeed' : '显示 Downpeed',
      newDownload: english ? 'New download…' : '新建下载…',
      quit: english ? 'Quit Downpeed' : '退出 Downpeed',
    );
  }

  @override
  void onClose() {
    _disposed = true;
    _windowHost.dispose();
    unawaited(_trayHost.destroy());
    super.onClose();
  }
}

class WindowManagerDesktopWindowHost implements DesktopWindowHost {
  _DesktopWindowListener? _listener;

  @override
  Future<void> initialize({required Future<void> Function() onClose}) async {
    await windowManager.ensureInitialized();
    _listener = _DesktopWindowListener(onClose);
    windowManager.addListener(_listener!);
  }

  @override
  Future<void> setPreventClose(bool value) =>
      windowManager.setPreventClose(value);

  @override
  Future<void> hide() => windowManager.hide();

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> focus() => windowManager.focus();

  @override
  Future<void> destroy() => windowManager.destroy();

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) windowManager.removeListener(listener);
    _listener = null;
  }
}

class _DesktopWindowListener with WindowListener {
  _DesktopWindowListener(this._onClose);

  final Future<void> Function() _onClose;

  @override
  void onWindowClose() {
    unawaited(_onClose());
  }
}

class SystemDesktopTrayHost implements DesktopTrayHost {
  _DesktopTrayListener? _listener;
  bool _iconCreated = false;

  @override
  Future<void> initialize({
    required DesktopTrayLabels labels,
    required Future<void> Function() onActivate,
    required Future<void> Function(DesktopTrayCommand command) onCommand,
  }) async {
    _listener = _DesktopTrayListener(
      onActivate: onActivate,
      onCommand: onCommand,
    );
    trayManager.addListener(_listener!);
    try {
      await trayManager.setIcon(
        _trayIconAsset,
        isTemplate: Platform.isMacOS,
        iconSize: 18,
      );
      _iconCreated = true;
      if (!Platform.isLinux) await trayManager.setToolTip('Downpeed');
      await updateMenu(labels);
    } on Object {
      trayManager.removeListener(_listener!);
      _listener = null;
      if (_iconCreated) {
        _iconCreated = false;
        try {
          await trayManager.destroy();
        } on Object {
          // Keep the initialization failure as the actionable error.
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> updateMenu(DesktopTrayLabels labels) =>
      trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show_window', label: labels.showWindow),
            MenuItem(key: 'new_download', label: labels.newDownload),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: labels.quit),
          ],
        ),
      );

  @override
  Future<void> destroy() async {
    final listener = _listener;
    if (listener != null) trayManager.removeListener(listener);
    _listener = null;
    if (_iconCreated) {
      _iconCreated = false;
      await trayManager.destroy();
    }
  }
}

class _DesktopTrayListener with TrayListener {
  _DesktopTrayListener({required this.onActivate, required this.onCommand});

  final Future<void> Function() onActivate;
  final Future<void> Function(DesktopTrayCommand command) onCommand;

  @override
  void onTrayIconMouseDown() {
    unawaited(onActivate());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final command = switch (menuItem.key) {
      'show_window' => DesktopTrayCommand.showWindow,
      'new_download' => DesktopTrayCommand.newDownload,
      'quit' => DesktopTrayCommand.quit,
      _ => null,
    };
    if (command != null) unawaited(onCommand(command));
  }
}

String get _trayIconAsset {
  if (Platform.isWindows) return 'windows/runner/resources/app_icon.ico';
  return 'assets/tray/downpeed_tray.svg';
}

bool get _isDesktopPlatform =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
