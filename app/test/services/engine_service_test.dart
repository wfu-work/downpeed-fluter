import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/download_resolution.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/services/engine_service.dart';
import 'package:downpeed_flutter/services/embedded_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/stub_engine_client.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('reports the connected engine and its version', () async {
    final service = EngineService(client: _FakeEngineClient(info: _info));

    await service.refresh();

    expect(service.state.value, EngineConnectionState.online);
    expect(service.info.value?.version, '0.1.0-test');
    expect(service.errorMessage.value, isNull);
  });

  test('normalizes an unavailable engine into offline state', () async {
    final service = EngineService(
      client: _FakeEngineClient(
        error: const EngineClientException('engine unavailable'),
      ),
    );

    await service.refresh();

    expect(service.state.value, EngineConnectionState.offline);
    expect(service.info.value, isNull);
    expect(service.errorMessage.value, 'engine unavailable');
  });

  test('retries the embedded host before probing the engine again', () async {
    final lifecycleHost = _FakeLifecycleHost();
    final embedded = EmbeddedEngineService(
      host: lifecycleHost,
      configurationLoader: () async => const <String, Object?>{
        'address': '127.0.0.1:17680',
      },
      mode: EmbeddedEngineMode.embedded,
      desktopSupported: true,
    );
    Get.put<EmbeddedEngineService>(embedded);
    final service = EngineService(client: _FakeEngineClient(info: _info));

    await service.refresh();

    expect(lifecycleHost.startCount, 1);
    expect(service.state.value, EngineConnectionState.online);
  });

  test('preserves an actionable embedded startup error', () async {
    final embedded = EmbeddedEngineService(
      host: _FakeLifecycleHost(
        error: const EmbeddedEngineException('address unavailable'),
      ),
      configurationLoader: () async => const <String, Object?>{
        'address': '127.0.0.1:17680',
      },
      mode: EmbeddedEngineMode.embedded,
      desktopSupported: true,
    );
    Get.put<EmbeddedEngineService>(embedded);
    final service = EngineService(
      client: _FakeEngineClient(
        error: const EngineClientException('engine unavailable'),
      ),
    );

    await service.refresh();

    expect(service.state.value, EngineConnectionState.offline);
    expect(service.errorMessage.value, 'address unavailable');
  });

  test(
    'auto mode falls back when a previously external engine stops',
    () async {
      final lifecycleHost = _FakeLifecycleHost();
      final client = _SequenceEngineClient(<Object>[
        const EngineClientException('external stopped'),
        const EngineClientException('external stopped'),
        _info,
      ]);
      final embedded = EmbeddedEngineService(
        host: lifecycleHost,
        probeClient: client,
        configurationLoader: () async => const <String, Object?>{
          'address': '127.0.0.1:17680',
        },
        mode: EmbeddedEngineMode.auto,
        desktopSupported: true,
      );
      embedded.state.value = EmbeddedEngineState.external;
      Get.put<EmbeddedEngineService>(embedded);
      final service = EngineService(client: client);

      await service.refresh();

      expect(lifecycleHost.startCount, 1);
      expect(embedded.state.value, EmbeddedEngineState.running);
      expect(service.state.value, EngineConnectionState.online);
    },
  );
}

const _info = EngineInfo(
  name: 'Downpeed Engine',
  version: '0.1.0-test',
  commit: 'test',
  apiVersion: 'v1',
  goVersion: 'go1.26',
  os: 'darwin',
  arch: 'arm64',
);

class _FakeEngineClient extends StubEngineClient {
  const _FakeEngineClient({this.info, this.error});

  final EngineInfo? info;
  final EngineClientException? error;

  @override
  Future<EngineInfo> fetchInfo() async {
    if (error case final error?) throw error;
    return info!;
  }

  @override
  Future<DownloadResolution> resolveDownload(String url) =>
      throw UnimplementedError();
}

class _FakeLifecycleHost implements EngineLifecycleHost {
  _FakeLifecycleHost({this.error});

  final Object? error;
  int startCount = 0;

  @override
  Future<void> start(Map<String, Object?> configuration) async {
    startCount++;
    if (error case final error?) throw error;
  }

  @override
  Future<void> stop() async {}
}

class _SequenceEngineClient extends StubEngineClient {
  _SequenceEngineClient(this.responses);

  final List<Object> responses;

  @override
  Future<EngineInfo> fetchInfo() async {
    final response = responses.removeAt(0);
    if (response is EngineInfo) return response;
    throw response;
  }
}
