import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../data/clients/engine_client.dart';

const _configuredEngineMode = String.fromEnvironment(
  'DOWNPEED_ENGINE_MODE',
  defaultValue: 'auto',
);
const _configuredEngineAddress = String.fromEnvironment(
  'DOWNPEED_ENGINE_ADDRESS',
  defaultValue: '127.0.0.1:17680',
);

enum EmbeddedEngineMode { auto, embedded, external }

enum EmbeddedEngineState { idle, external, starting, running, failed, stopped }

abstract interface class EngineLifecycleHost {
  Future<void> start(Map<String, Object?> configuration);

  Future<void> stop();
}

typedef EngineConfigurationLoader = Future<Map<String, Object?>> Function();

class EmbeddedEngineException implements Exception {
  const EmbeddedEngineException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmbeddedEngineService extends GetxService with WidgetsBindingObserver {
  EmbeddedEngineService({
    this.host,
    this.probeClient,
    this.configurationLoader,
    EmbeddedEngineMode? mode,
    bool? desktopSupported,
  }) : mode = mode ?? parseEmbeddedEngineMode(_configuredEngineMode),
       _desktopSupported = desktopSupported ?? _isDesktopPlatform;

  static EmbeddedEngineService get to => Get.find<EmbeddedEngineService>();

  final EngineLifecycleHost? host;
  final EngineClient? probeClient;
  final EngineConfigurationLoader? configurationLoader;
  final EmbeddedEngineMode mode;
  final bool _desktopSupported;
  final state = EmbeddedEngineState.idle.obs;
  final errorMessage = RxnString();
  Future<void>? _initializing;
  bool _ownsEngine = false;
  bool _observingLifecycle = false;
  EngineLifecycleHost? _activeHost;

  bool get ownsEngine => _ownsEngine;

  Future<void> initialize() =>
      _initializing ??= _initialize().whenComplete(() => _initializing = null);

  Future<void> _initialize() async {
    errorMessage.value = null;
    if (mode == EmbeddedEngineMode.external || !_desktopSupported) {
      state.value = EmbeddedEngineState.external;
      return;
    }
    if (mode == EmbeddedEngineMode.auto && await _externalEngineIsOnline()) {
      state.value = EmbeddedEngineState.external;
      return;
    }

    state.value = EmbeddedEngineState.starting;
    try {
      final activeHost = host ?? FfiEngineLifecycleHost.open();
      final configuration =
          await (configurationLoader ?? _defaultEmbeddedConfiguration)();
      await activeHost.start(configuration);
      _activeHost = activeHost;
      _ownsEngine = true;
      state.value = EmbeddedEngineState.running;
      if (!_observingLifecycle) {
        WidgetsBinding.instance.addObserver(this);
        _observingLifecycle = true;
      }
    } on Object catch (error) {
      _ownsEngine = false;
      final message = error is EmbeddedEngineException
          ? error.message
          : 'The embedded Downpeed engine could not start.';
      errorMessage.value = message;
      state.value = EmbeddedEngineState.failed;
    }
  }

  Future<bool> _externalEngineIsOnline() async {
    try {
      await (probeClient ?? DioEngineClient()).fetchInfo();
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> shutdown() async {
    if (!_ownsEngine) return;
    _ownsEngine = false;
    try {
      await (_activeHost ?? host ?? FfiEngineLifecycleHost.open()).stop();
      _activeHost = null;
      state.value = EmbeddedEngineState.stopped;
    } on Object catch (error) {
      errorMessage.value = error is EmbeddedEngineException
          ? error.message
          : 'The embedded Downpeed engine could not stop cleanly.';
      state.value = EmbeddedEngineState.failed;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(shutdown());
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await shutdown();
    return AppExitResponse.exit;
  }

  @override
  void onClose() {
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    unawaited(shutdown());
    super.onClose();
  }
}

Future<Map<String, Object?>> _defaultEmbeddedConfiguration() async {
  final applicationSupport = await getApplicationSupportDirectory();
  final downloads = await getDownloadsDirectory();
  return <String, Object?>{
    'address': _configuredEngineAddress,
    'dataDir': applicationSupport.path,
    'defaultDownloadDirectory':
        downloads?.path ??
        '${applicationSupport.path}${Platform.pathSeparator}Downloads',
  };
}

EmbeddedEngineMode parseEmbeddedEngineMode(String value) =>
    switch (value.trim().toLowerCase()) {
      'embedded' => EmbeddedEngineMode.embedded,
      'external' => EmbeddedEngineMode.external,
      _ => EmbeddedEngineMode.auto,
    };

class FfiEngineLifecycleHost implements EngineLifecycleHost {
  FfiEngineLifecycleHost._(this._bindings);

  factory FfiEngineLifecycleHost.open({DynamicLibrary? library}) =>
      FfiEngineLifecycleHost._(
        _EngineBindings(library ?? DynamicLibrary.open(_libraryPath())),
      );

  final _EngineBindings _bindings;

  @override
  Future<void> start(Map<String, Object?> configuration) => _callBlocking(() {
    final jsonPointer = jsonEncode(configuration).toNativeUtf8();
    try {
      final result = _bindings.start(jsonPointer.cast<Char>());
      if (result != 0) throw EmbeddedEngineException(_lastError());
    } finally {
      malloc.free(jsonPointer);
    }
  });

  @override
  Future<void> stop() => _callBlocking(() {
    final result = _bindings.stop();
    if (result != 0) throw EmbeddedEngineException(_lastError());
  });

  String _lastError() {
    final requiredLength = _bindings.lastError(nullptr, 0);
    if (requiredLength <= 1 || requiredLength > 64 << 10) {
      return 'The embedded Downpeed engine operation failed.';
    }
    final buffer = calloc<Uint8>(requiredLength);
    try {
      _bindings.lastError(buffer.cast<Char>(), requiredLength);
      return buffer.cast<Utf8>().toDartString();
    } finally {
      calloc.free(buffer);
    }
  }
}

Future<T> _callBlocking<T>(T Function() callback) => Future<T>.sync(callback);

typedef _StartNative = Int32 Function(Pointer<Char>);
typedef _StartDart = int Function(Pointer<Char>);
typedef _StopNative = Int32 Function();
typedef _StopDart = int Function();
typedef _LastErrorNative = Int32 Function(Pointer<Char>, Int32);
typedef _LastErrorDart = int Function(Pointer<Char>, int);

class _EngineBindings {
  _EngineBindings(DynamicLibrary library)
    : start = library.lookupFunction<_StartNative, _StartDart>('DownpeedStart'),
      stop = library.lookupFunction<_StopNative, _StopDart>('DownpeedStop'),
      lastError = library.lookupFunction<_LastErrorNative, _LastErrorDart>(
        'DownpeedLastError',
      );

  final _StartDart start;
  final _StopDart stop;
  final _LastErrorDart lastError;
}

String _libraryPath() {
  final executableDirectory = File(Platform.resolvedExecutable).parent;
  if (Platform.isMacOS) {
    return '${executableDirectory.parent.path}/Frameworks/libdownpeed.dylib';
  }
  if (Platform.isWindows) {
    return '${executableDirectory.path}\\downpeed.dll';
  }
  if (Platform.isLinux) {
    return '${executableDirectory.path}/lib/libdownpeed.so';
  }
  throw const EmbeddedEngineException(
    'The embedded Downpeed engine is not supported on this platform.',
  );
}

bool get _isDesktopPlatform =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
