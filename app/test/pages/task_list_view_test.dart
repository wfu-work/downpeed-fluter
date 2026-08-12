import 'dart:async';

import 'package:downpeed_flutter/configs/theme/downpeed_theme_tokens.dart';
import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/batch_task_result.dart';
import 'package:downpeed_flutter/domains/download_resolution.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/main.dart';
import 'package:downpeed_flutter/services/directory_picker.dart';
import 'package:downpeed_flutter/services/engine_service.dart';
import 'package:downpeed_flutter/services/desktop_actions_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/stub_engine_client.dart';
import '../support/stub_directory_picker.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('task toolbar keeps its description visually subordinate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TaskListEngineClient(const <DownloadTask>[]);
    addTearDown(client.close);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('task-toolbar-title')),
    );
    final subtitleFinder = find.byKey(const ValueKey('task-toolbar-subtitle'));
    final subtitle = tester.widget<Text>(subtitleFinder);

    expect(title.style?.fontSize, DownpeedThemeTokens.textTitle);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(subtitle.style?.fontSize, DownpeedThemeTokens.textCaption);
    expect(
      subtitle.style?.color,
      tester.element(subtitleFinder).downpeedColors.textMuted,
    );
  });

  testWidgets('opens a fresh new-download modal without leaving tasks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TaskListEngineClient(const <DownloadTask>[]);
    addTearDown(client.close);
    Get.put<DirectoryPicker>(
      const StubDirectoryPicker(result: '/tmp/downpeed-downloads'),
      permanent: true,
    );
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    final tasksRoute = Get.currentRoute;

    await tester.tap(find.byKey(const ValueKey('add-download-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('create-download-dialog')),
      findsOneWidget,
    );
    final dialogSize = tester.getSize(
      find.byKey(const ValueKey('create-download-dialog')),
    );
    expect(dialogSize.width, 720);
    expect(dialogSize.height, 450);
    expect(find.byKey(const ValueKey('create-download-intro')), findsOneWidget);
    expect(find.byKey(const ValueKey('download-url-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('create-download-idle-hint')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('download-url-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-search-field')), findsOneWidget);
    expect(Get.currentRoute, tasksRoute);

    await tester.enterText(
      find.byKey(const ValueKey('download-url-field')),
      'https://example.com/old.zip',
    );
    await tester.tap(
      find.byKey(const ValueKey('close-create-download-dialog')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-download-dialog')), findsNothing);
    expect(Get.currentRoute, tasksRoute);

    await tester.tap(find.byKey(const ValueKey('add-download-button')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('download-url-field')),
    );
    expect(field.controller?.text, isEmpty);
    await tester.tap(
      find.byKey(const ValueKey('close-create-download-dialog')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a new download with the keyboard shortcut', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TaskListEngineClient(const <DownloadTask>[]);
    addTearDown(client.close);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('create-download-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('close-create-download-dialog')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('new-download modal adapts to a narrow high-scale window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final client = _TaskListEngineClient(const <DownloadTask>[]);
    addTearDown(client.close);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-download-button')));
    await tester.pumpAndSettle();

    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('create-download-dialog')),
    );
    expect(dialogRect.left, greaterThanOrEqualTo(8));
    expect(dialogRect.right, lessThanOrEqualTo(382));
    expect(find.byKey(const ValueKey('download-url-field')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('close-create-download-dialog')))
          .height,
      44,
    );
    await tester.tap(
      find.byKey(const ValueKey('close-create-download-dialog')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolves and creates a download inside the modal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TaskListEngineClient(const <DownloadTask>[]);
    addTearDown(client.close);
    Get.put<DirectoryPicker>(
      const StubDirectoryPicker(result: '/tmp/downpeed-downloads'),
      permanent: true,
    );
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-download-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('download-url-field')),
      'https://example.com/modal.zip',
    );
    await tester.pump();
    final resolveButton = find.byKey(const ValueKey('resolve-download-button'));
    await tester.ensureVisible(resolveButton);
    await tester.tap(resolveButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('resolve-success-panel')), findsOneWidget);
    final chooseDirectory = find.byKey(
      const ValueKey('choose-save-directory-button'),
    );
    await tester.ensureVisible(chooseDirectory);
    await tester.tap(chooseDirectory);
    await tester.pumpAndSettle();
    final startDownload = find.byKey(const ValueKey('start-download-button'));
    await tester.ensureVisible(startDownload);
    await tester.tap(startDownload);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active-download-panel')), findsOneWidget);
    expect(client.resolveCalls, 1);
    expect(client.createCalls, 1);
    expect(
      find.byKey(const ValueKey('create-download-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('close-create-download-dialog')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-search-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide task list opens the detail inspector and pauses', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TaskListEngineClient([
      _task('active-1', DownloadTaskState.downloading),
    ]);
    addTearDown(client.close);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-row-active-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-speed-active-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('task-progress-active-1')),
      findsOneWidget,
    );
    expect(find.text('50%'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('select-all-visible'))).dx,
      tester.getTopLeft(find.byKey(const ValueKey('select-task-active-1'))).dx,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('task-row-active-1'))).height,
      lessThan(90),
    );
    expect(find.text('选择一个任务'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('task-row-active-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-detail-active-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pause-task-active-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resume-task-active-1')), findsOneWidget);
    expect(client.pauseCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact task list navigates to an independent detail page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TaskListEngineClient([
      _task('paused-1', DownloadTaskState.paused),
    ]);
    addTearDown(client.close);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-row-paused-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-detail-paused-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('detail-resume-paused-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('detail-cancel-paused-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('detail-resume-paused-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-pause-paused-1')), findsOneWidget);
    expect(client.resumeCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters, searches, and pauses a selected task in one batch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TaskListEngineClient([
      _task('active-1', DownloadTaskState.downloading, fileName: 'zeta.zip'),
      _task('paused-1', DownloadTaskState.paused, fileName: 'alpha.zip'),
      _task('completed-1', DownloadTaskState.completed, fileName: 'done.zip'),
    ]);
    addTearDown(client.close);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('已完成'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-row-completed-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-row-active-1')), findsNothing);

    await tester.tap(find.text('全部任务'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-search-field')),
      'alpha',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-row-paused-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-row-active-1')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('task-search-field')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文件名'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('task-row-paused-1'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('task-row-active-1'))).dy,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('select-task-active-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('batch-command-strip')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('batch-pause-button')));
    await tester.pumpAndSettle();

    expect(client.batchCalls, 1);
    expect(client.lastBatchAction, BatchTaskAction.pause);
    expect(client.lastBatchIds, <String>['active-1']);
    expect(find.byKey(const ValueKey('batch-command-strip')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders all task states and a long name at 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final client = _TaskListEngineClient([
      _task(
        'active',
        DownloadTaskState.downloading,
        fileName: 'Downpeed-2026-完整离线资料包-包含设计资源与开发文档-最终发布版本-arm64.zip',
      ),
      _task('paused', DownloadTaskState.paused),
      _task('completed', DownloadTaskState.completed),
      _task('failed', DownloadTaskState.failed),
    ]);
    addTearDown(client.close);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();

    expect(find.text('正在传输'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('已暂停'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('已暂停'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('下载完成'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('下载完成'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('下载未完成'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('下载未完成'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains that a changed remote file was stopped safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TaskListEngineClient([
      _task(
        'changed-1',
        DownloadTaskState.failed,
        errorCode: 'remote_resource_changed',
      ),
    ]);
    addTearDown(client.close);
    await _registerOnlineEngine(client);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-row-changed-1')));
    await tester.pumpAndSettle();

    expect(
      find.text('远端文件已更新。为避免拼接新旧内容，Downpeed 已停止续传，请重新创建任务。'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens and reveals a completed file from the task workspace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TaskListEngineClient([
      _task('completed-1', DownloadTaskState.completed),
    ]);
    addTearDown(client.close);
    final platform = _WidgetDesktopActions();
    await _registerOnlineEngine(client, desktopPlatform: platform);

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-task-completed-1')));
    await tester.pumpAndSettle();
    expect(platform.openedPaths, <String>['/tmp/downloads/archive.zip']);

    await tester.tap(find.byKey(const ValueKey('task-row-completed-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('detail-open-file-completed-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('detail-reveal-file-completed-1')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('detail-reveal-file-completed-1')),
    );
    await tester.pumpAndSettle();
    expect(platform.revealedPaths, <String>['/tmp/downloads/archive.zip']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains when a completed file was moved or deleted', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TaskListEngineClient([
      _task('completed-1', DownloadTaskState.completed),
    ]);
    addTearDown(client.close);
    await _registerOnlineEngine(
      client,
      desktopPlatform: _WidgetDesktopActions(openErrorCode: 'file_not_found'),
    );

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-task-completed-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('file-action-message')), findsOneWidget);
    expect(find.text('文件已被移动或删除，无法执行此操作。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _registerOnlineEngine(
  _TaskListEngineClient client, {
  DesktopActionsPlatform? desktopPlatform,
}) async {
  Get.put<EngineClient>(client, permanent: true);
  if (desktopPlatform != null) {
    Get.put<DesktopActionsService>(
      DesktopActionsService(platform: desktopPlatform),
      permanent: true,
    );
  }
  final engine = EngineService(client: client);
  Get.put<EngineService>(engine, permanent: true);
  await engine.refresh();
}

class _WidgetDesktopActions implements DesktopActionsPlatform {
  _WidgetDesktopActions({this.openErrorCode});

  final String? openErrorCode;
  final openedPaths = <String>[];
  final revealedPaths = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<void> openFile(String path) async {
    if (openErrorCode case final code?) throw DesktopActionException(code);
    openedPaths.add(path);
  }

  @override
  Future<void> revealFile(String path) async {
    revealedPaths.add(path);
  }

  @override
  Future<void> showCompletionNotification({
    required String id,
    required String title,
    required String body,
  }) async {}
}

class _TaskListEngineClient extends StubEngineClient {
  _TaskListEngineClient(this.initialTasks);

  final List<DownloadTask> initialTasks;
  final _events = StreamController<DownloadTaskEvent>.broadcast();
  int pauseCalls = 0;
  int resumeCalls = 0;
  int batchCalls = 0;
  int resolveCalls = 0;
  int createCalls = 0;
  BatchTaskAction? lastBatchAction;
  List<String> lastBatchIds = const <String>[];

  @override
  Future<EngineInfo> fetchInfo() async => _info;

  @override
  Future<List<DownloadTask>> fetchTasks() async => initialTasks;

  @override
  Future<DownloadResolution> resolveDownload(String url) async {
    resolveCalls++;
    return DownloadResolution(
      url: url,
      finalUrl: url,
      fileName: 'modal.zip',
      size: 1024,
      contentType: 'application/zip',
      acceptRanges: true,
    );
  }

  @override
  Future<DownloadTask> createTask({
    required String url,
    required String fileName,
    required String saveDirectory,
    int expectedSize = -1,
    bool acceptRanges = false,
    String etag = '',
    String lastModified = '',
  }) async {
    createCalls++;
    return _task('modal-1', DownloadTaskState.downloading, fileName: fileName);
  }

  @override
  Future<DownloadTask> fetchTask(String id) async =>
      initialTasks.firstWhere((task) => task.id == id);

  @override
  Future<DownloadTask> pauseTask(String id) async {
    pauseCalls++;
    return _task(id, DownloadTaskState.paused);
  }

  @override
  Future<DownloadTask> resumeTask(String id) async {
    resumeCalls++;
    return _task(id, DownloadTaskState.downloading);
  }

  @override
  Future<DownloadTask> cancelTask(String id) async =>
      _task(id, DownloadTaskState.canceled);

  @override
  Future<BatchTaskResult> actOnTasks(
    List<String> ids,
    BatchTaskAction action,
  ) async {
    batchCalls++;
    lastBatchAction = action;
    lastBatchIds = ids;
    final state = switch (action) {
      BatchTaskAction.pause => DownloadTaskState.paused,
      BatchTaskAction.resume => DownloadTaskState.downloading,
      BatchTaskAction.cancel => DownloadTaskState.canceled,
    };
    return BatchTaskResult(
      items: <BatchTaskItemResult>[
        for (var index = 0; index < ids.length; index++)
          BatchTaskItemResult(
            index: index,
            id: ids[index],
            task: _task(ids[index], state),
          ),
      ],
      succeeded: ids.length,
      failed: 0,
    );
  }

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => _events.stream;

  Future<void> close() => _events.close();
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

DownloadTask _task(
  String id,
  DownloadTaskState state, {
  String fileName = 'archive.zip',
  String errorCode = 'download_failed',
}) {
  final now = DateTime.utc(2026, 8, 11, 1);
  return DownloadTask(
    id: id,
    url: 'https://example.com/$fileName',
    finalUrl: 'https://cdn.example.com/$fileName',
    fileName: fileName,
    saveDirectory: '/tmp/downloads',
    filePath: '/tmp/downloads/$fileName',
    state: state,
    downloaded: state == DownloadTaskState.completed ? 1024 : 512,
    total: 1024,
    speedBps: state == DownloadTaskState.downloading ? 128 : 0,
    error: state == DownloadTaskState.failed
        ? DownloadTaskError(
            code: errorCode,
            message: 'failed',
            retryable: errorCode != 'remote_resource_changed',
          )
        : null,
    createdAt: now,
    updatedAt: now,
    completedAt: state == DownloadTaskState.completed ? now : null,
  );
}
