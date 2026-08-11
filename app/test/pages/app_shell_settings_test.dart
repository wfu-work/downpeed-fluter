import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
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

  testWidgets('collapses, expands, and resizes the desktop sidebar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _registerOnlineEngine();

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();

    expect(find.text('Downpeed'), findsNothing);
    expect(
      find.byKey(const ValueKey('sidebar-toggle-expanded')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sidebar-resize-handle')), findsOneWidget);
    final initialWidth = tester
        .getSize(find.byKey(const ValueKey('sidebar-pane')))
        .width;

    await tester.tap(find.byKey(const ValueKey('sidebar-toggle-expanded')));
    await tester.pump();

    final collapsedWidth = tester
        .getSize(find.byKey(const ValueKey('sidebar-pane')))
        .width;
    expect(collapsedWidth, lessThan(initialWidth));
    expect(find.byKey(const ValueKey('sidebar-resize-handle')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sidebar-toggle-collapsed')));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('sidebar-resize-handle')),
      const Offset(48, 0),
    );
    await tester.pump();

    final resizedWidth = tester
        .getSize(find.byKey(const ValueKey('sidebar-pane')))
        .width;
    expect(resizedWidth, closeTo(initialWidth + 48, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens settings and keeps task navigation available', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _registerOnlineEngine();

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar-settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-theme-control')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-language-control')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('sidebar-filter-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-page')), findsNothing);
    expect(find.text('下载任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _registerOnlineEngine() async {
  final engine = EngineService(client: const _ShellEngineClient());
  Get.put<EngineService>(engine, permanent: true);
  await engine.refresh();
}

class _ShellEngineClient extends StubEngineClient {
  const _ShellEngineClient();

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
  Future<List<DownloadTask>> fetchTasks() async => const [];

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => const Stream.empty();
}
