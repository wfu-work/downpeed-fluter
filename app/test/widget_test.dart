import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/download_resolution.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/main.dart';
import 'package:downpeed_flutter/services/engine_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/stub_engine_client.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('shows the ready transfer workspace when engine is online', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = EngineService(client: const _FakeEngineClient(info: _info));
    Get.put<EngineService>(engine, permanent: true);
    await engine.refresh();

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();

    expect(find.text('还没有下载任务'), findsOneWidget);
    expect(find.text('已连接'), findsOneWidget);
    expect(find.text('本机引擎 · 0.1.0-test'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-download-button')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('add-download-button')));
    await tester.pumpAndSettle();
    expect(find.text('检查下载链接'), findsOneWidget);
  });

  testWidgets('shows an actionable offline state on a compact layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final engine = EngineService(
      client: const _FakeEngineClient(
        error: EngineClientException('engine unavailable'),
      ),
    );
    Get.put<EngineService>(engine, permanent: true);
    await engine.refresh();

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();

    expect(find.text('引擎未连接'), findsOneWidget);
    expect(find.text('重新连接'), findsOneWidget);
    expect(find.textContaining('go run ./cmd/downpeedd'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
  Future<List<DownloadTask>> fetchTasks() async => const [];

  @override
  Future<DownloadResolution> resolveDownload(String url) =>
      throw UnimplementedError();
}
