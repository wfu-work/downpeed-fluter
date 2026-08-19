import 'package:flutter/services.dart';

abstract interface class ProxyCredentialStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> delete();
}

class MethodChannelProxyCredentialStore implements ProxyCredentialStore {
  const MethodChannelProxyCredentialStore();

  static const _channel = MethodChannel('com.xiaoxi.downpeed/secure_storage');
  static const _key = 'proxy-password';

  @override
  Future<String?> read() =>
      _channel.invokeMethod<String>('read', {'key': _key});

  @override
  Future<void> write(String value) =>
      _channel.invokeMethod<void>('write', {'key': _key, 'value': value});

  @override
  Future<void> delete() => _channel.invokeMethod<void>('delete', {'key': _key});
}
