import 'package:downpeed_flutter/services/desktop_integration_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initializes window interception and a usable tray menu', () async {
    final window = _FakeWindowHost();
    final tray = _FakeTrayHost();
    final service = DesktopIntegrationService(
      windowHost: window,
      trayHost: tray,
      desktopSupported: true,
    );

    await service.initialize();

    expect(window.initializeCount, 1);
    expect(window.preventCloseValues, <bool>[true]);
    expect(tray.initializeCount, 1);
    expect(tray.labels?.showWindow, isNotEmpty);
    expect(service.windowReady.value, isTrue);
    expect(service.trayAvailable.value, isTrue);
  });

  test('close hides the window while tray mode is enabled', () async {
    final window = _FakeWindowHost();
    final tray = _FakeTrayHost();
    var engineStopCount = 0;
    final service = DesktopIntegrationService(
      windowHost: window,
      trayHost: tray,
      shutdownEngine: () async => engineStopCount++,
      closeToTrayEnabled: () => true,
      desktopSupported: true,
    );
    await service.initialize();

    await tray.requestClose(window);

    expect(window.hideCount, 1);
    expect(window.destroyCount, 0);
    expect(engineStopCount, 0);
    expect(service.isQuitting.value, isFalse);
  });

  test('close fully exits when tray mode is disabled', () async {
    final window = _FakeWindowHost();
    final tray = _FakeTrayHost();
    var engineStopCount = 0;
    final service = DesktopIntegrationService(
      windowHost: window,
      trayHost: tray,
      shutdownEngine: () async => engineStopCount++,
      closeToTrayEnabled: () => false,
      desktopSupported: true,
    );
    await service.initialize();

    await service.handleCloseRequested();

    expect(window.preventCloseValues, <bool>[true, false]);
    expect(tray.destroyCount, 1);
    expect(engineStopCount, 1);
    expect(window.destroyCount, 1);
    expect(service.isQuitting.value, isTrue);
  });

  test('tray commands restore, create, and quit without fallthrough', () async {
    final window = _FakeWindowHost();
    final tray = _FakeTrayHost();
    var createCount = 0;
    var engineStopCount = 0;
    final service = DesktopIntegrationService(
      windowHost: window,
      trayHost: tray,
      shutdownEngine: () async => engineStopCount++,
      openNewDownload: () async => createCount++,
      desktopSupported: true,
    );
    await service.initialize();

    await tray.select(DesktopTrayCommand.showWindow);
    expect(window.showCount, 1);
    expect(window.focusCount, 1);
    expect(createCount, 0);

    await tray.select(DesktopTrayCommand.newDownload);
    expect(window.showCount, 2);
    expect(window.focusCount, 2);
    expect(createCount, 1);
    expect(engineStopCount, 0);

    await tray.select(DesktopTrayCommand.quit);
    expect(engineStopCount, 1);
    expect(window.destroyCount, 1);
  });

  test('missing tray falls back to a clean exit on close', () async {
    final window = _FakeWindowHost();
    final tray = _FakeTrayHost(initializeError: StateError('unavailable'));
    var engineStopCount = 0;
    final service = DesktopIntegrationService(
      windowHost: window,
      trayHost: tray,
      shutdownEngine: () async => engineStopCount++,
      closeToTrayEnabled: () => true,
      desktopSupported: true,
    );
    await service.initialize();

    expect(service.trayAvailable.value, isFalse);
    await service.handleCloseRequested();

    expect(window.hideCount, 0);
    expect(engineStopCount, 1);
    expect(window.destroyCount, 1);
  });

  test('unsupported platforms do not initialize desktop plugins', () async {
    final window = _FakeWindowHost();
    final tray = _FakeTrayHost();
    final service = DesktopIntegrationService(
      windowHost: window,
      trayHost: tray,
      desktopSupported: false,
    );

    await service.initialize();

    expect(window.initializeCount, 0);
    expect(tray.initializeCount, 0);
    expect(service.isSupported, isFalse);
  });

  test('login launch stays hidden when quiet startup is enabled', () async {
    final window = _FakeWindowHost();
    final service = DesktopIntegrationService(
      windowHost: window,
      trayHost: _FakeTrayHost(),
      startHiddenOnLogin: () => true,
      desktopSupported: true,
    );

    await service.initialize(
      launchArguments: const [downpeedStartupLaunchArgument],
    );

    expect(window.hideCount, 1);
    expect(window.showCount, 0);
    expect(window.focusCount, 0);
  });

  test(
    'login launch shows the window when quiet startup is disabled',
    () async {
      final window = _FakeWindowHost();
      final service = DesktopIntegrationService(
        windowHost: window,
        trayHost: _FakeTrayHost(),
        startHiddenOnLogin: () => false,
        desktopSupported: true,
      );

      await service.initialize(
        launchArguments: const [downpeedStartupLaunchArgument],
      );

      expect(window.hideCount, 0);
      expect(window.showCount, 1);
      expect(window.focusCount, 1);
    },
  );

  test(
    'missing tray forces a login launch window to remain accessible',
    () async {
      final window = _FakeWindowHost();
      final service = DesktopIntegrationService(
        windowHost: window,
        trayHost: _FakeTrayHost(initializeError: StateError('unavailable')),
        startHiddenOnLogin: () => true,
        desktopSupported: true,
      );

      await service.initialize(
        launchArguments: const [downpeedStartupLaunchArgument],
      );

      expect(window.hideCount, 0);
      expect(window.showCount, 1);
      expect(window.focusCount, 1);
    },
  );

  test('manual launch is visible even when quiet startup is enabled', () async {
    final window = _FakeWindowHost();
    final service = DesktopIntegrationService(
      windowHost: window,
      trayHost: _FakeTrayHost(),
      startHiddenOnLogin: () => true,
      desktopSupported: true,
    );

    await service.initialize();

    expect(window.hideCount, 0);
    expect(window.showCount, 0);
    expect(window.focusCount, 0);
  });
}

class _FakeWindowHost implements DesktopWindowHost {
  Future<void> Function()? onClose;
  int initializeCount = 0;
  int hideCount = 0;
  int showCount = 0;
  int focusCount = 0;
  int destroyCount = 0;
  final preventCloseValues = <bool>[];

  @override
  Future<void> initialize({required Future<void> Function() onClose}) async {
    initializeCount++;
    this.onClose = onClose;
  }

  @override
  Future<void> setPreventClose(bool value) async {
    preventCloseValues.add(value);
  }

  @override
  Future<void> hide() async => hideCount++;

  @override
  Future<void> show() async => showCount++;

  @override
  Future<void> focus() async => focusCount++;

  @override
  Future<void> destroy() async => destroyCount++;

  @override
  void dispose() {}
}

class _FakeTrayHost implements DesktopTrayHost {
  _FakeTrayHost({this.initializeError});

  final Object? initializeError;
  Future<void> Function()? onActivate;
  Future<void> Function(DesktopTrayCommand command)? onCommand;
  DesktopTrayLabels? labels;
  int initializeCount = 0;
  int destroyCount = 0;

  @override
  Future<void> initialize({
    required DesktopTrayLabels labels,
    required Future<void> Function() onActivate,
    required Future<void> Function(DesktopTrayCommand command) onCommand,
  }) async {
    initializeCount++;
    if (initializeError case final error?) throw error;
    this.labels = labels;
    this.onActivate = onActivate;
    this.onCommand = onCommand;
  }

  @override
  Future<void> updateMenu(DesktopTrayLabels labels) async {
    this.labels = labels;
  }

  @override
  Future<void> destroy() async => destroyCount++;

  Future<void> select(DesktopTrayCommand command) async {
    await onCommand?.call(command);
  }

  Future<void> requestClose(_FakeWindowHost window) async {
    await window.onClose?.call();
  }
}
