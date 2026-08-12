import 'dart:async';

import 'package:downpeed_flutter/app/pages/create_download/create_download_controller.dart';
import 'package:downpeed_flutter/app/routes/app_pages.dart';
import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/batch_task_result.dart';
import 'package:downpeed_flutter/domains/bt_resolution.dart';
import 'package:downpeed_flutter/domains/download_resolution.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/main.dart';
import 'package:downpeed_flutter/services/directory_picker.dart';
import 'package:downpeed_flutter/services/torrent_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/stub_engine_client.dart';
import '../support/stub_directory_picker.dart';
import '../support/stub_torrent_file_picker.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('shows resolved metadata in the focused wide layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Get.put<EngineClient>(
      const _FakeEngineClient(result: _standardResolution),
      permanent: true,
    );

    await tester.pumpWidget(
      const DownpeedApp(initialRoute: Routes.createDownload),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('download-url-field')),
      'https://example.com/file.zip',
    );
    await tester.pump();
    final resolveButton = find.byKey(const ValueKey('resolve-download-button'));
    await tester.ensureVisible(resolveButton);
    await tester.tap(resolveButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('resolve-success-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('resolved-file-name')), findsOneWidget);
    expect(find.text('cdn.example.com'), findsOneWidget);
    expect(find.text('1.5 MB'), findsOneWidget);
    expect(find.text('支持 Range'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles a long filename at 200 percent text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    Get.put<EngineClient>(
      const _FakeEngineClient(result: _longResolution),
      permanent: true,
    );

    await tester.pumpWidget(
      const DownpeedApp(initialRoute: Routes.createDownload),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('download-url-field')),
      'https://downloads.example.com/long-file-name.zip',
    );
    await tester.pump();
    final resolveButton = find.byKey(const ValueKey('resolve-download-button'));
    await tester.ensureVisible(resolveButton);
    await tester.tap(resolveButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('resolved-file-name')), findsOneWidget);
    expect(find.text(_longFileName), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates, updates, and cancels a download task', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _TransferEngineClient();
    addTearDown(client.close);
    Get.put<EngineClient>(client, permanent: true);
    Get.put<DirectoryPicker>(
      const StubDirectoryPicker(result: '/tmp/downpeed-downloads'),
      permanent: true,
    );

    await tester.pumpWidget(
      const DownpeedApp(initialRoute: Routes.createDownload),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('download-url-field')),
      _standardResolution.url,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('resolve-download-button')));
    await tester.pumpAndSettle();

    final chooseDirectory = find.byKey(
      const ValueKey('choose-save-directory-button'),
    );
    await tester.ensureVisible(chooseDirectory);
    await tester.tap(chooseDirectory);
    await tester.pumpAndSettle();
    expect(find.text('/tmp/downpeed-downloads'), findsOneWidget);

    final startDownload = find.byKey(const ValueKey('start-download-button'));
    await tester.ensureVisible(startDownload);
    await tester.tap(startDownload);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-download-panel')), findsOneWidget);

    client.emit(_task(DownloadTaskState.downloading, downloaded: 524288));
    await tester.pumpAndSettle();
    expect(find.text('512 KB / 1 MB'), findsOneWidget);

    final cancelDownload = find.byKey(const ValueKey('cancel-download-button'));
    await tester.ensureVisible(cancelDownload);
    await tester.tap(cancelDownload);
    await tester.pumpAndSettle();
    expect(find.text('下载已取消'), findsOneWidget);
    expect(client.cancelCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows multiline resolutions and a batch creation summary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _BatchTransferEngineClient();
    Get.put<EngineClient>(client, permanent: true);
    Get.put<DirectoryPicker>(
      const StubDirectoryPicker(result: '/tmp/downpeed-downloads'),
      permanent: true,
    );

    await tester.pumpWidget(
      const DownpeedApp(initialRoute: Routes.createDownload),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('download-url-field')),
      'https://example.com/one.zip\nhttps://example.com/two.zip',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('resolve-download-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('batch-resolve-success-panel')),
      findsOneWidget,
    );
    expect(find.text('one.zip'), findsOneWidget);
    expect(find.text('two.zip'), findsOneWidget);

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

    expect(find.byKey(const ValueKey('batch-created-panel')), findsOneWidget);
    expect(find.text('成功 2 个 · 失败 0 个'), findsOneWidget);
    expect(client.createdInputs, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Torrent files and updates the selected size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Get.put<EngineClient>(
      const _BTResolverEngineClient(result: _torrentResolution),
      permanent: true,
    );
    Get.put<TorrentFilePicker>(
      const StubTorrentFilePicker(
        result: PickedTorrentFile(
          name: 'downpeed-archive.torrent',
          bytes: <int>[1, 2, 3],
        ),
      ),
      permanent: true,
    );

    await tester.pumpWidget(
      const DownpeedApp(initialRoute: Routes.createDownload),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('advanced-options')));
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('choose-torrent-file-button'));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bt-resolution-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('bt-file-list')), findsOneWidget);
    expect(find.text('已选择 2 / 2 个文件 · 3 KB'), findsOneWidget);

    final secondFile = find.byKey(const ValueKey('bt-file-checkbox-1'));
    await tester.ensureVisible(secondFile);
    await tester.tap(secondFile);
    await tester.pump();

    expect(find.text('已选择 1 / 2 个文件 · 1 KB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a restricted BT task at 200 percent text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 920));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final client = _BTTransferEngineClient();
    addTearDown(client.close);
    Get.put<EngineClient>(client, permanent: true);
    Get.put<TorrentFilePicker>(
      const StubTorrentFilePicker(
        result: PickedTorrentFile(
          name: 'downpeed-archive.torrent',
          bytes: <int>[1, 2, 3],
        ),
      ),
      permanent: true,
    );
    Get.put<DirectoryPicker>(
      const StubDirectoryPicker(result: '/tmp/downpeed-downloads'),
      permanent: true,
    );

    await tester.pumpWidget(
      const DownpeedApp(initialRoute: Routes.createDownload),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('advanced-options')));
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('choose-torrent-file-button'));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();

    final directory = find.byKey(
      const ValueKey('bt-choose-save-directory-button'),
    );
    await tester.ensureVisible(directory);
    await tester.tap(directory);
    await tester.pumpAndSettle();
    final peers = find.byKey(const ValueKey('bt-explicit-peers-field'));
    await tester.ensureVisible(peers);
    await tester.enterText(peers, '8.8.8.8:6881');
    await tester.pump();

    final controller = Get.find<CreateDownloadController>();
    expect(controller.saveDirectory.value, '/tmp/downpeed-downloads');
    expect(controller.canCreateBTTask, isTrue);
    final start = find.byKey(const ValueKey('start-bt-download-button'));
    await tester.ensureVisible(start);
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(client.metadata, <int>[1, 2, 3]);
    expect(controller.phase.value, CreateDownloadPhase.downloading);
    expect(find.byKey(const ValueKey('active-download-panel')), findsOneWidget);
    expect(find.text('Peer 连接'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains offline Magnet parsing at 200 percent text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    Get.put<EngineClient>(
      const _BTResolverEngineClient(result: _magnetResolution),
      permanent: true,
    );

    await tester.pumpWidget(
      const DownpeedApp(initialRoute: Routes.createDownload),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('download-url-field')),
      _magnetUri,
    );
    await tester.pump();
    final resolveButton = find.byKey(const ValueKey('resolve-download-button'));
    await tester.ensureVisible(resolveButton);
    await tester.tap(resolveButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bt-resolution-panel')), findsOneWidget);
    expect(find.textContaining('不会连接 Tracker、DHT 或 Peer'), findsOneWidget);
    expect(find.byKey(const ValueKey('bt-file-list')), findsNothing);
    expect(
      find.byKey(const ValueKey('start-bt-download-button')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

const _standardResolution = DownloadResolution(
  url: 'https://example.com/file.zip',
  finalUrl: 'https://cdn.example.com/file.zip',
  fileName: 'file.zip',
  size: 1572864,
  contentType: 'application/zip',
  acceptRanges: true,
);

const _longFileName = 'Downpeed-2026-完整离线资料包-包含设计资源与开发文档-最终发布版本-arm64.zip';

const _longResolution = DownloadResolution(
  url: 'https://downloads.example.com/long-file-name.zip',
  finalUrl: 'https://cdn.downloads.example.com/long-file-name.zip',
  fileName: _longFileName,
  size: -1,
  contentType: '',
  acceptRanges: false,
);

const _infoHash = '0123456789abcdef0123456789abcdef01234567';
const _magnetUri = 'magnet:?xt=urn:btih:$_infoHash';

const _magnetResolution = BTResolution(
  sourceType: BTSourceType.magnet,
  name: 'Downpeed Archive',
  infoHash: _infoHash,
  v2InfoHash: '',
  metadataAvailable: false,
  isPrivate: false,
  totalSize: -1,
  pieceLength: 0,
  files: <BTFileEntry>[],
  trackers: <BTTracker>[
    BTTracker(scheme: 'https', host: 'tracker.example.com'),
  ],
);

const _torrentResolution = BTResolution(
  sourceType: BTSourceType.torrent,
  name: 'Downpeed Archive',
  infoHash: _infoHash,
  v2InfoHash: '',
  metadataAvailable: true,
  isPrivate: true,
  totalSize: 3072,
  pieceLength: 16384,
  files: <BTFileEntry>[
    BTFileEntry(index: 0, path: 'Downpeed Archive/one.bin', size: 1024),
    BTFileEntry(index: 1, path: 'Downpeed Archive/two.bin', size: 2048),
  ],
  trackers: <BTTracker>[
    BTTracker(scheme: 'https', host: 'tracker.example.com'),
  ],
);

class _FakeEngineClient extends StubEngineClient {
  const _FakeEngineClient({required this.result});

  final DownloadResolution result;

  @override
  Future<EngineInfo> fetchInfo() => throw UnimplementedError();

  @override
  Future<DownloadResolution> resolveDownload(String url) async => result;
}

class _BTResolverEngineClient extends StubEngineClient {
  const _BTResolverEngineClient({required this.result});

  final BTResolution result;

  @override
  Future<BTResolution> resolveMagnet(String magnet) async => result;

  @override
  Future<BTResolution> resolveTorrent(List<int> bytes) async => result;
}

class _BTTransferEngineClient extends StubEngineClient {
  final _events = StreamController<DownloadTaskEvent>.broadcast();
  List<int>? metadata;

  @override
  Future<BTResolution> resolveTorrent(List<int> bytes) async =>
      _torrentResolution;

  @override
  Future<DownloadTask> createBTTask({
    required List<int> metadata,
    required String saveDirectory,
    required List<int> selectedFileIndexes,
    required List<String> explicitPeers,
  }) async {
    this.metadata = metadata;
    return _task(
      DownloadTaskState.downloading,
      protocol: DownloadProtocol.bt,
      connections: 2,
    );
  }

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => _events.stream;

  Future<void> close() => _events.close();
}

class _TransferEngineClient extends StubEngineClient {
  final _events = StreamController<DownloadTaskEvent>.broadcast();
  int cancelCalls = 0;

  @override
  Future<DownloadResolution> resolveDownload(String url) async =>
      _standardResolution;

  @override
  Future<DownloadTask> createTask({
    required String url,
    required String fileName,
    required String saveDirectory,
    int expectedSize = -1,
    bool acceptRanges = false,
    String etag = '',
    String lastModified = '',
  }) async => _task(DownloadTaskState.downloading);

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => _events.stream;

  @override
  Future<DownloadTask> cancelTask(String id) async {
    cancelCalls++;
    return _task(DownloadTaskState.canceled, downloaded: 524288);
  }

  void emit(DownloadTask task) {
    _events.add(DownloadTaskEvent(type: 'task.updated', task: task));
  }

  Future<void> close() => _events.close();
}

class _BatchTransferEngineClient extends StubEngineClient {
  List<CreateTaskInput> createdInputs = const <CreateTaskInput>[];

  @override
  Future<DownloadResolution> resolveDownload(String url) async {
    final fileName = Uri.parse(url).pathSegments.last;
    return DownloadResolution(
      url: url,
      finalUrl: url,
      fileName: fileName,
      size: 1048576,
      contentType: 'application/zip',
      acceptRanges: true,
    );
  }

  @override
  Future<BatchTaskResult> createTasks(List<CreateTaskInput> tasks) async {
    createdInputs = tasks;
    return BatchTaskResult(
      items: <BatchTaskItemResult>[
        for (var index = 0; index < tasks.length; index++)
          BatchTaskItemResult(
            index: index,
            id: 'task-$index',
            task: _task(DownloadTaskState.queued),
          ),
      ],
      succeeded: tasks.length,
      failed: 0,
    );
  }
}

DownloadTask _task(
  DownloadTaskState state, {
  int downloaded = 0,
  DownloadProtocol protocol = DownloadProtocol.http,
  int connections = 0,
}) {
  final now = DateTime.utc(2026, 8, 11);
  return DownloadTask(
    id: 'task-1',
    url: _standardResolution.url,
    finalUrl: _standardResolution.finalUrl,
    fileName: _standardResolution.fileName,
    saveDirectory: '/tmp/downpeed-downloads',
    filePath: '/tmp/downpeed-downloads/file.zip',
    state: state,
    downloaded: downloaded,
    total: 1048576,
    speedBps: state == DownloadTaskState.downloading ? 262144 : 0,
    protocol: protocol,
    connections: connections,
    createdAt: now,
    updatedAt: now,
    completedAt: state == DownloadTaskState.downloading ? null : now,
  );
}
