import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'desktop_integration_service.dart';

enum StartupFailure { read, update, verification }

abstract interface class StartupHost {
  Future<bool> isSupported();

  Future<bool> isEnabled();

  Future<bool> setEnabled(bool value);
}

class StartupService extends GetxService {
  StartupService({StartupHost? host}) : _host = host ?? SystemStartupHost();

  static StartupService get to => Get.find<StartupService>();

  final StartupHost _host;
  final supported = false.obs;
  final enabled = false.obs;
  final isLoading = false.obs;
  final failure = Rxn<StartupFailure>();

  Future<void>? _initializing;

  Future<void> initialize() =>
      _initializing ??= _initialize().whenComplete(() => _initializing = null);

  Future<void> _initialize() async {
    isLoading.value = true;
    failure.value = null;
    try {
      supported.value = await _host.isSupported();
      enabled.value = supported.value ? await _host.isEnabled() : false;
    } on Object {
      supported.value = false;
      enabled.value = false;
      failure.value = StartupFailure.read;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> setEnabled(bool value) async {
    if (!supported.value || isLoading.value) return false;
    final previous = enabled.value;
    isLoading.value = true;
    failure.value = null;
    try {
      final updated = await _host.setEnabled(value);
      final actual = await _host.isEnabled();
      if (!updated || actual != value) {
        enabled.value = actual;
        failure.value = StartupFailure.verification;
        return false;
      }
      enabled.value = actual;
      return true;
    } on Object {
      try {
        enabled.value = await _host.isEnabled();
      } on Object {
        enabled.value = previous;
      }
      failure.value = StartupFailure.update;
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}

class SystemStartupHost implements StartupHost {
  static const _channel = MethodChannel('com.xiaoxi.downpeed/startup');
  bool _configured = false;

  @override
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    if (Platform.isMacOS) {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    }
    return Platform.isWindows || Platform.isLinux;
  }

  @override
  Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    if (Platform.isMacOS) {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    }
    _configurePortableHost();
    return launchAtStartup.isEnabled();
  }

  @override
  Future<bool> setEnabled(bool value) async {
    if (kIsWeb) return false;
    if (Platform.isMacOS) {
      return await _channel.invokeMethod<bool>('setEnabled', value) ?? false;
    }
    _configurePortableHost();
    return value
        ? await launchAtStartup.enable()
        : await launchAtStartup.disable();
  }

  void _configurePortableHost() {
    if (_configured) return;
    var executable = Platform.resolvedExecutable;
    final isMsix =
        Platform.isWindows &&
        executable.contains('WindowsApps') &&
        executable.contains('com.xiaoxi.downpeed');
    if (Platform.isWindows && !isMsix) {
      executable = '"$executable"';
    } else if (Platform.isLinux) {
      executable = '"${executable.replaceAll('"', r'\"')}"';
    }
    launchAtStartup.setup(
      appName: 'Downpeed',
      appPath: executable,
      packageName: 'com.xiaoxi.downpeed',
      args: const [downpeedStartupLaunchArgument],
    );
    _configured = true;
  }
}
