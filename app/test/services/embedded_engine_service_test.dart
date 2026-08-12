import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/services/embedded_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stub_engine_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('embedded mode starts and owns the lifecycle host', () async {
    final host = _FakeLifecycleHost();
    final service = EmbeddedEngineService(
      host: host,
      configurationLoader: _testConfiguration,
      mode: EmbeddedEngineMode.embedded,
      desktopSupported: true,
    );

    await service.initialize();

    expect(host.startCount, 1);
    expect(host.configuration, <String, Object?>{'address': '127.0.0.1:17680'});
    expect(service.state.value, EmbeddedEngineState.running);
    expect(service.ownsEngine, isTrue);

    await service.shutdown();
    expect(host.stopCount, 1);
    expect(service.state.value, EmbeddedEngineState.stopped);
  });

  test('external mode never opens the embedded host', () async {
    final host = _FakeLifecycleHost();
    final service = EmbeddedEngineService(
      host: host,
      configurationLoader: _testConfiguration,
      mode: EmbeddedEngineMode.external,
      desktopSupported: true,
    );

    await service.initialize();
    await service.shutdown();

    expect(host.startCount, 0);
    expect(host.stopCount, 0);
    expect(service.state.value, EmbeddedEngineState.external);
  });

  test('auto mode preserves a reachable external engine', () async {
    final host = _FakeLifecycleHost();
    final service = EmbeddedEngineService(
      host: host,
      probeClient: const _OnlineEngineClient(),
      configurationLoader: _testConfiguration,
      mode: EmbeddedEngineMode.auto,
      desktopSupported: true,
    );

    await service.initialize();

    expect(host.startCount, 0);
    expect(service.state.value, EmbeddedEngineState.external);
    expect(service.ownsEngine, isFalse);
  });

  test('auto mode starts embedded engine after a failed probe', () async {
    final host = _FakeLifecycleHost();
    final service = EmbeddedEngineService(
      host: host,
      probeClient: const _OfflineEngineClient(),
      configurationLoader: _testConfiguration,
      mode: EmbeddedEngineMode.auto,
      desktopSupported: true,
    );

    await service.initialize();

    expect(host.startCount, 1);
    expect(service.state.value, EmbeddedEngineState.running);
  });

  test('host startup errors remain actionable', () async {
    final service = EmbeddedEngineService(
      host: _FakeLifecycleHost(
        startError: const EmbeddedEngineException('address unavailable'),
      ),
      configurationLoader: _testConfiguration,
      mode: EmbeddedEngineMode.embedded,
      desktopSupported: true,
    );

    await service.initialize();

    expect(service.state.value, EmbeddedEngineState.failed);
    expect(service.errorMessage.value, 'address unavailable');
    expect(service.ownsEngine, isFalse);
  });

  test('parses supported modes and safely defaults unknown values', () {
    expect(parseEmbeddedEngineMode(' EMBEDDED '), EmbeddedEngineMode.embedded);
    expect(parseEmbeddedEngineMode('external'), EmbeddedEngineMode.external);
    expect(parseEmbeddedEngineMode('unknown'), EmbeddedEngineMode.auto);
  });
}

Future<Map<String, Object?>> _testConfiguration() async =>
    const <String, Object?>{'address': '127.0.0.1:17680'};

class _FakeLifecycleHost implements EngineLifecycleHost {
  _FakeLifecycleHost({this.startError});

  final Object? startError;
  int startCount = 0;
  int stopCount = 0;
  Map<String, Object?>? configuration;

  @override
  Future<void> start(Map<String, Object?> configuration) async {
    startCount++;
    this.configuration = configuration;
    if (startError case final error?) throw error;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _OnlineEngineClient extends StubEngineClient {
  const _OnlineEngineClient();

  @override
  Future<EngineInfo> fetchInfo() async => const EngineInfo(
    name: 'Downpeed Engine',
    version: 'test',
    commit: 'test',
    apiVersion: 'v1',
    goVersion: 'go1.26',
    os: 'darwin',
    arch: 'arm64',
  );
}

class _OfflineEngineClient extends StubEngineClient {
  const _OfflineEngineClient();

  @override
  Future<EngineInfo> fetchInfo() =>
      throw const EngineClientException('offline', code: 'engine_unreachable');
}
