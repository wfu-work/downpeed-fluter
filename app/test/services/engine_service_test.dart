import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/download_resolution.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/services/engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stub_engine_client.dart';

void main() {
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
