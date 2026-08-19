import 'package:downpeed_flutter/domains/engine_settings.dart';
import 'package:downpeed_flutter/services/engine_settings_service.dart';
import 'package:downpeed_flutter/services/proxy_credential_store.dart';
import 'package:downpeed_flutter/services/proxy_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stub_engine_client.dart';

void main() {
  test('restores the secure password into engine memory at startup', () async {
    final client = _ProxyEngineClient();
    final settings = EngineSettingsService(client: client);
    await settings.load();
    final store = _MemoryCredentialStore(value: 'secure-password');
    final service = ProxySettingsService(
      client: client,
      engineSettings: settings,
      credentialStore: store,
    );

    await service.initialize();

    expect(service.hasStoredPassword.value, isTrue);
    expect(client.credentials, <String>['secure-password']);
  });

  test(
    'saves non-secret settings and password through separate stores',
    () async {
      final client = _ProxyEngineClient();
      final settings = EngineSettingsService(client: client);
      await settings.load();
      final store = _MemoryCredentialStore();
      final service = ProxySettingsService(
        client: client,
        engineSettings: settings,
        credentialStore: store,
      );
      const proxy = ProxySettings(
        mode: ProxyMode.http,
        host: 'proxy.example',
        port: 8080,
        username: 'downpeed',
        connectTimeoutSeconds: 8,
        responseHeaderTimeoutSeconds: 20,
      );

      expect(
        await service.save(proxy, replacementPassword: 'new-password'),
        isTrue,
      );

      expect(settings.proxy?.host, 'proxy.example');
      expect(settings.proxy?.username, 'downpeed');
      expect(store.value, 'new-password');
      expect(client.credentials, <String>['new-password']);
      expect(service.hasStoredPassword.value, isTrue);
    },
  );

  test('does not change engine settings when secure storage fails', () async {
    final client = _ProxyEngineClient();
    final settings = EngineSettingsService(client: client);
    await settings.load();
    final service = ProxySettingsService(
      client: client,
      engineSettings: settings,
      credentialStore: _MemoryCredentialStore(failWrites: true),
    );
    const proxy = ProxySettings(
      mode: ProxyMode.socks5,
      host: 'proxy.example',
      port: 1080,
      username: '',
      connectTimeoutSeconds: 10,
      responseHeaderTimeoutSeconds: 30,
    );

    expect(
      await service.save(proxy, replacementPassword: 'not-persisted'),
      isFalse,
    );

    expect(settings.proxy?.mode, ProxyMode.direct);
    expect(client.credentials, isEmpty);
    expect(service.credentialStoreAvailable.value, isFalse);
  });
}

class _MemoryCredentialStore implements ProxyCredentialStore {
  _MemoryCredentialStore({this.value, this.failWrites = false});

  String? value;
  final bool failWrites;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('vault unavailable');
    this.value = value;
  }

  @override
  Future<void> delete() async {
    if (failWrites) throw StateError('vault unavailable');
    value = null;
  }
}

class _ProxyEngineClient extends StubEngineClient {
  EngineSettings current = _initialSettings;
  final credentials = <String>[];

  @override
  Future<EngineSettings> fetchSettings() async => current;

  @override
  Future<EngineSettings> updateSettings({
    required String defaultDownloadDirectory,
    required FileConflictPolicy fileConflictPolicy,
    required SchedulerSettings scheduler,
    required ProxySettings proxy,
    required BTPolicySettings bitTorrent,
  }) async {
    current = EngineSettings(
      defaultDownloadDirectory: defaultDownloadDirectory,
      fileConflictPolicy: fileConflictPolicy,
      scheduler: scheduler,
      proxy: proxy,
      bitTorrent: bitTorrent,
    );
    return current;
  }

  @override
  Future<void> updateProxyCredential(String password) async {
    credentials.add(password);
  }
}

const _initialSettings = EngineSettings(
  defaultDownloadDirectory: '/tmp/Downloads',
  fileConflictPolicy: FileConflictPolicy.fail,
  scheduler: SchedulerSettings(
    maxConcurrentTasks: 3,
    downloadRateLimit: 0,
    maxRetries: 2,
  ),
  proxy: ProxySettings(
    mode: ProxyMode.direct,
    host: '',
    port: 0,
    username: '',
    connectTimeoutSeconds: 10,
    responseHeaderTimeoutSeconds: 30,
  ),
  bitTorrent: BTPolicySettings(
    maxPeerConnections: 80,
    explicitPeersOnly: true,
    trackersEnabled: false,
    dhtEnabled: false,
    pexEnabled: false,
    webSeedsEnabled: false,
    inboundEnabled: false,
    ipv6Enabled: false,
    uploadEnabled: false,
    seedingEnabled: false,
  ),
);
