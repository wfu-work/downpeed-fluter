import 'package:downpeed_flutter/app/routes/app_pages.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/domains/engine_settings.dart';
import 'package:downpeed_flutter/main.dart';
import 'package:downpeed_flutter/services/engine_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/stub_engine_client.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('desktop sidebar switches between the new destinations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const client = _WorkspaceEngineClient([]);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('sidebar-destination-overview')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-subtitle')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sidebar-destination-network')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('network-title')), findsOneWidget);
    expect(Get.currentRoute, Routes.network);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview summarizes real task data on desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _WorkspaceEngineClient([
      _task('active', DownloadTaskState.downloading, speedBps: 2048),
      _task('retrying', DownloadTaskState.retrying, speedBps: 1024),
      _task('queued', DownloadTaskState.queued),
      _task('paused', DownloadTaskState.paused),
      _task('completed', DownloadTaskState.completed),
      _task('failed', DownloadTaskState.failed),
    ]);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp(initialRoute: Routes.overview));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('overview-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-subtitle')), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-tools')), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-activity')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('overview-current-speed')))
          .data,
      '3.00 KB/s',
    );
    expect(_metricValue(tester, 'active'), '2');
    expect(_metricValue(tester, 'queued'), '2');
    expect(_metricValue(tester, 'completed'), '1');
    expect(_metricValue(tester, 'issues'), '1');
    expect(find.byKey(const ValueKey('overview-task-active')), findsWidgets);
    expect(
      find.byKey(const ValueKey('overview-task-completed')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sidebar-destination-overview')),
        matching: find.byKey(const ValueKey('sidebar-selected-indicator')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'network shows engine settings and restricted policy on desktop',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const client = _WorkspaceEngineClient([]);
      await _registerOnlineEngine(client);

      await tester.pumpWidget(const DownpeedApp(initialRoute: Routes.network));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('network-engine-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('network-download-boundary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('network-scheduler-section')),
        findsOneWidget,
      );
      expect(find.text('4 个任务'), findsOneWidget);
      expect(find.text('5.00 MB/s'), findsOneWidget);
      expect(find.text('3 次'), findsOneWidget);
      expect(find.text('/tmp/Downpeed Downloads'), findsOneWidget);
      expect(find.text('24 个连接'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('network-policy-section')),
        findsOneWidget,
      );
      expect(find.text('受限策略正常'), findsOneWidget);
      expect(find.text('Tracker'), findsOneWidget);
      expect(find.text('已关闭'), findsNWidgets(8));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sidebar-destination-network')),
          matching: find.byKey(const ValueKey('sidebar-selected-indicator')),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overview remains usable at 390 pixels and 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final client = _WorkspaceEngineClient([
      _task(
        'active',
        DownloadTaskState.downloading,
        speedBps: 4096,
        fileName: 'Downpeed-2026-完整离线资料包-包含设计资源与开发文档-最终发布版本.zip',
      ),
      _task('completed', DownloadTaskState.completed),
    ]);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp(initialRoute: Routes.overview));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('overview-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-summary')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('overview-recent-tasks')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('overview-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const ValueKey('overview-recent-tasks')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network remains usable at 390 pixels and 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    const client = _WorkspaceEngineClient([]);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp(initialRoute: Routes.network));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('network-title')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('network-scheduler-section')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('network-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const ValueKey('network-scheduler-section')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('network-policy-section')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('network-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const ValueKey('network-policy-status')), findsOneWidget);
    expect(find.text('受限策略正常'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String? _metricValue(WidgetTester tester, String id) =>
    tester.widget<Text>(find.byKey(ValueKey('overview-metric-$id-value'))).data;

Future<void> _registerOnlineEngine(_WorkspaceEngineClient client) async {
  final engine = EngineService(client: client);
  Get.put<EngineService>(engine, permanent: true);
  await engine.refresh();
}

class _WorkspaceEngineClient extends StubEngineClient {
  const _WorkspaceEngineClient(this.tasks);

  final List<DownloadTask> tasks;

  @override
  Future<EngineInfo> fetchInfo() async => const EngineInfo(
    name: 'Downpeed Engine',
    version: '0.1.0-test',
    commit: 'test',
    apiVersion: 'v1',
    goVersion: 'go1.26',
    os: 'darwin',
    arch: 'arm64',
  );

  @override
  Future<List<DownloadTask>> fetchTasks() async => tasks;

  @override
  Future<EngineSettings> fetchSettings() async => _settings;

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => const Stream.empty();
}

const _settings = EngineSettings(
  defaultDownloadDirectory: '/tmp/Downpeed Downloads',
  fileConflictPolicy: FileConflictPolicy.fail,
  scheduler: SchedulerSettings(
    maxConcurrentTasks: 4,
    downloadRateLimit: 5 * 1024 * 1024,
    maxRetries: 3,
  ),
  bitTorrent: BTPolicySettings(
    maxPeerConnections: 24,
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

DownloadTask _task(
  String id,
  DownloadTaskState state, {
  int speedBps = 0,
  String fileName = 'archive.zip',
}) {
  final now = DateTime.utc(2026, 8, 17, 10);
  return DownloadTask(
    id: id,
    url: 'https://example.com/$fileName',
    finalUrl: 'https://cdn.example.com/$fileName',
    fileName: fileName,
    saveDirectory: '/tmp/Downpeed Downloads',
    filePath: '/tmp/Downpeed Downloads/$fileName',
    state: state,
    downloaded: state == DownloadTaskState.completed ? 4096 : 2048,
    total: 4096,
    speedBps: speedBps,
    error: state == DownloadTaskState.failed
        ? const DownloadTaskError(
            code: 'download_failed',
            message: 'failed',
            retryable: true,
          )
        : null,
    createdAt: now,
    updatedAt: now,
    completedAt: state == DownloadTaskState.completed ? now : null,
  );
}
