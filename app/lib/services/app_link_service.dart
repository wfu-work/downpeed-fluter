import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app_command_service.dart';

const downpeedAppLinkChannel = 'com.xiaoxi.downpeed/app_links';
const maxDownpeedAppLinkBytes = 8192;

enum DownpeedAppLinkError {
  tooLong,
  malformed,
  unsupportedCommand,
  invalidParameters,
  invalidTarget,
}

class DownpeedAppLinkException implements Exception {
  const DownpeedAppLinkException(this.code);

  final DownpeedAppLinkError code;

  @override
  String toString() => 'DownpeedAppLinkException(${code.name})';
}

class DownpeedDownloadLink {
  const DownpeedDownloadLink({required this.targetUrl});

  final String targetUrl;
}

class DownpeedAppLinkParser {
  const DownpeedAppLinkParser();

  DownpeedDownloadLink parse(String source) {
    if (source.length > maxDownpeedAppLinkBytes ||
        utf8.encode(source).length > maxDownpeedAppLinkBytes) {
      throw const DownpeedAppLinkException(DownpeedAppLinkError.tooLong);
    }
    if (!source.startsWith('downpeed://') ||
        source.codeUnits.any(_isControlCharacter)) {
      throw const DownpeedAppLinkException(DownpeedAppLinkError.malformed);
    }

    final Uri uri;
    try {
      uri = Uri.parse(source);
    } on FormatException {
      throw const DownpeedAppLinkException(DownpeedAppLinkError.malformed);
    }
    if (uri.scheme != 'downpeed' ||
        !uri.hasAuthority ||
        uri.host != 'download' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path.isNotEmpty ||
        uri.hasFragment) {
      throw const DownpeedAppLinkException(
        DownpeedAppLinkError.unsupportedCommand,
      );
    }
    final parameters = uri.queryParametersAll;
    final targets = parameters['url'];
    if (!uri.hasQuery ||
        parameters.length != 1 ||
        targets == null ||
        targets.length != 1) {
      throw const DownpeedAppLinkException(
        DownpeedAppLinkError.invalidParameters,
      );
    }

    final targetUrl = targets.single;
    if (targetUrl.isEmpty || targetUrl.codeUnits.any(_isControlCharacter)) {
      throw const DownpeedAppLinkException(DownpeedAppLinkError.invalidTarget);
    }
    final Uri target;
    try {
      target = Uri.parse(targetUrl);
    } on FormatException {
      throw const DownpeedAppLinkException(DownpeedAppLinkError.invalidTarget);
    }
    if ((target.scheme != 'http' && target.scheme != 'https') ||
        !target.hasAuthority ||
        target.host.isEmpty ||
        target.userInfo.isNotEmpty) {
      throw const DownpeedAppLinkException(DownpeedAppLinkError.invalidTarget);
    }
    return DownpeedDownloadLink(targetUrl: targetUrl);
  }

  DownpeedDownloadLink? tryParse(String source) {
    try {
      return parse(source);
    } on DownpeedAppLinkException {
      return null;
    }
  }

  static bool _isControlCharacter(int value) => value < 0x20 || value == 0x7f;
}

abstract interface class AppLinkPlatform {
  Future<void> listen(ValueChanged<String> onUri);

  Future<void> dispose();
}

class MethodChannelAppLinkPlatform implements AppLinkPlatform {
  MethodChannelAppLinkPlatform({
    this._channel = const MethodChannel(downpeedAppLinkChannel),
  });

  final MethodChannel _channel;

  @override
  Future<void> listen(ValueChanged<String> onUri) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openUri' && call.arguments is String) {
        onUri(call.arguments as String);
      }
    });
    try {
      await _channel.invokeMethod<void>('ready');
    } on MissingPluginException {
      // Non-desktop hosts do not provide the app-link channel.
    } on PlatformException {
      // A native integration failure must not block application startup.
    }
  }

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
  }
}

class AppLinkService extends GetxService {
  AppLinkService({
    AppLinkPlatform? platform,
    this._commands,
    this._parser = const DownpeedAppLinkParser(),
  }) : _platform = platform ?? MethodChannelAppLinkPlatform();

  static AppLinkService get to => Get.find<AppLinkService>();

  final AppLinkPlatform _platform;
  final AppCommandService? _commands;
  final DownpeedAppLinkParser _parser;
  bool _initialized = false;

  Future<void> initialize({List<String> launchArguments = const []}) async {
    if (_initialized) return;
    _initialized = true;
    await _platform.listen(_handleUri);
    for (final argument in launchArguments) {
      _handleUri(argument);
    }
  }

  void _handleUri(String uri) {
    handleUri(uri);
  }

  bool handleUri(String source) {
    final link = _parser.tryParse(source);
    if (link == null) return false;
    unawaited(
      (_commands ?? AppCommandService.to).openExternalDownload(
        initialUrl: link.targetUrl,
      ),
    );
    return true;
  }

  @override
  void onClose() {
    unawaited(_platform.dispose());
    super.onClose();
  }
}
