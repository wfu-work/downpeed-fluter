import 'package:downpeed_flutter/app/routes/app_pages.dart';
import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/domains/engine_settings.dart';
import 'package:downpeed_flutter/main.dart';
import 'package:downpeed_flutter/services/app_link_service.dart';
import 'package:downpeed_flutter/services/engine_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/stub_engine_client.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('application shortcuts work across primary destinations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _ShortcutEngineClient();
    Get.put<EngineClient>(client, permanent: true);
    final engine = EngineService(client: client);
    Get.put<EngineService>(engine, permanent: true);
    await engine.refresh();

    await tester.pumpWidget(const DownpeedApp(initialRoute: Routes.overview));
    await tester.pumpAndSettle();

    await _sendControlShortcut(tester, LogicalKeyboardKey.comma);
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.settings);
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);

    final infoCallsBeforeRefresh = client.infoCalls;
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyR);
    await tester.pumpAndSettle();
    expect(client.infoCalls, greaterThan(infoCallsBeforeRefresh));

    await _sendControlShortcut(tester, LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.tasks);
    final search = tester.widget<TextField>(
      find.byKey(const ValueKey('task-search-field')),
    );
    expect(search.focusNode?.hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('sidebar-destination-network')));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.network);

    await _sendControlShortcut(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('create-download-dialog')),
      findsOneWidget,
    );
    expect(Get.currentRoute, Routes.tasks);
  });

  testWidgets('app link restores tasks and only prefills the download dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _ShortcutEngineClient();
    Get.put<EngineClient>(client, permanent: true);
    final engine = EngineService(client: client);
    Get.put<EngineService>(engine, permanent: true);
    await engine.refresh();

    await tester.pumpWidget(const DownpeedApp(initialRoute: Routes.overview));
    await tester.pumpAndSettle();
    const target = 'https://example.com/prefilled.zip';
    final source = Uri(
      scheme: 'downpeed',
      host: 'download',
      queryParameters: const <String, String>{'url': target},
    ).toString();

    expect(AppLinkService.to.handleUri(source), isTrue);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.tasks);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('download-url-field')))
          .controller
          ?.text,
      target,
    );
    expect(client.createCalls, 0);
  });
}

Future<void> _sendControlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

class _ShortcutEngineClient extends StubEngineClient {
  int infoCalls = 0;
  int createCalls = 0;

  @override
  Future<EngineInfo> fetchInfo() async {
    infoCalls++;
    return const EngineInfo(
      name: 'Downpeed Engine',
      version: 'test',
      commit: 'test',
      apiVersion: 'v1',
      goVersion: 'go1.26',
      os: 'darwin',
      arch: 'arm64',
    );
  }

  @override
  Future<List<DownloadTask>> fetchTasks() async => const <DownloadTask>[];

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => const Stream.empty();

  @override
  Future<EngineSettings> fetchSettings() async => _settings;

  @override
  Future<DownloadTask> createTask({
    required String url,
    required String fileName,
    required String saveDirectory,
    int expectedSize = -1,
    bool acceptRanges = false,
    String etag = '',
    String lastModified = '',
    DateTime? scheduledAt,
  }) {
    createCalls++;
    throw UnimplementedError();
  }
}

const _settings = EngineSettings(
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
