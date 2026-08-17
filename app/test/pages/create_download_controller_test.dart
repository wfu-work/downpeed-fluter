import 'dart:async';

import 'package:downpeed_flutter/app/pages/create_download/create_download_controller.dart';
import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/batch_task_result.dart';
import 'package:downpeed_flutter/domains/bt_resolution.dart';
import 'package:downpeed_flutter/domains/download_resolution.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/services/torrent_file_picker.dart';
import 'package:downpeed_flutter/services/engine_settings_service.dart';
import 'package:downpeed_flutter/domains/engine_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stub_directory_picker.dart';
import '../support/stub_engine_client.dart';
import '../support/stub_torrent_file_picker.dart';

const _testBTPolicy = BTPolicySettings(
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
);

void main() {
  test('resolves a valid online HTTP source', () async {
    final client = _FakeEngineClient(result: _resolution);
    final controller = CreateDownloadController(
      client: client,
      directoryPicker: const StubDirectoryPicker(),
    );
    controller.onInit();
    addTearDown(controller.onClose);
    controller.urlController.text = 'https://example.com/file.zip';

    await controller.resolve();

    expect(controller.phase.value, CreateDownloadPhase.resolved);
    expect(controller.resolution.value?.fileName, 'file.zip');
    expect(client.resolveCalls, 1);
  });

  test('shows an actionable normalized resolver error', () async {
    final client = _FakeEngineClient(
      error: const EngineClientException(
        'backend detail',
        code: 'resolve_failed',
      ),
    );
    final controller = CreateDownloadController(
      client: client,
      directoryPicker: const StubDirectoryPicker(),
    );
    controller.onInit();
    addTearDown(controller.onClose);
    controller.urlController.text = 'https://example.com/missing.zip';

    await controller.resolve();

    expect(controller.phase.value, CreateDownloadPhase.failed);
    expect(controller.errorMessage.value, isNot('backend detail'));
    expect(client.resolveCalls, 1);
  });

  test(
    'rejects invalid and unsupported URLs before calling the engine',
    () async {
      final client = _FakeEngineClient(result: _resolution);
      final controller = CreateDownloadController(
        client: client,
        directoryPicker: const StubDirectoryPicker(),
      );
      controller.onInit();
      addTearDown(controller.onClose);

      controller.urlController.text = 'not a URL';
      await controller.resolve();
      expect(controller.phase.value, CreateDownloadPhase.failed);

      controller.urlController.text = 'ftp://example.com/file.zip';
      await controller.resolve();
      expect(controller.phase.value, CreateDownloadPhase.failed);
      expect(client.resolveCalls, 0);
    },
  );

  test('resolves Magnet identity without starting network metadata', () async {
    final client = _FakeEngineClient(btResult: _magnetResolution);
    final controller = CreateDownloadController(
      client: client,
      directoryPicker: const StubDirectoryPicker(),
    );
    controller.onInit();
    addTearDown(controller.onClose);
    controller.urlController.text =
        'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567';

    await controller.resolve();

    expect(controller.phase.value, CreateDownloadPhase.resolved);
    expect(controller.btResolution.value?.sourceType, BTSourceType.magnet);
    expect(controller.btResolution.value?.metadataAvailable, isFalse);
    expect(client.resolveMagnetCalls, 1);
    expect(client.resolveCalls, 0);
  });

  test('loads Torrent metadata and tracks selected file size', () async {
    final client = _FakeEngineClient(btResult: _torrentResolution);
    final controller = CreateDownloadController(
      client: client,
      directoryPicker: const StubDirectoryPicker(),
      torrentFilePicker: const StubTorrentFilePicker(
        result: PickedTorrentFile(
          name: 'archive.torrent',
          bytes: <int>[1, 2, 3],
        ),
      ),
    );
    controller.onInit();
    addTearDown(controller.onClose);

    await controller.chooseTorrentFile();

    expect(controller.phase.value, CreateDownloadPhase.resolved);
    expect(controller.torrentFileName.value, 'archive.torrent');
    expect(controller.selectedBTFileCount, 2);
    expect(controller.selectedBTSize, 3072);
    controller.toggleBTFile(1);
    expect(controller.selectedBTFileCount, 1);
    expect(controller.selectedBTSize, 1024);
    expect(client.resolveTorrentCalls, 1);
  });

  test(
    'clears protocol-specific state when switching HTTP and Torrent',
    () async {
      final client = _FakeEngineClient(
        result: _resolution,
        btResult: _torrentResolution,
      );
      final controller = CreateDownloadController(
        client: client,
        directoryPicker: const StubDirectoryPicker(),
        torrentFilePicker: const StubTorrentFilePicker(
          result: PickedTorrentFile(
            name: 'archive.torrent',
            bytes: <int>[1, 2, 3],
          ),
        ),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      controller.urlController.text = _resolution.url;

      await controller.resolve();
      expect(controller.resolutions, hasLength(1));

      await controller.chooseTorrentFile();
      expect(controller.resolutions, isEmpty);
      expect(controller.hasTorrentMetadata, isTrue);
      controller.explicitPeersController.text = '8.8.8.8:6881';

      await controller.resolve();
      expect(controller.btResolution.value, isNull);
      expect(controller.hasTorrentMetadata, isFalse);
      expect(controller.explicitPeersInput.value, isEmpty);
      expect(controller.peerInputError.value, isNull);
      expect(controller.resolutions, hasLength(1));
      expect(controller.canCreateTask, isFalse);

      controller.saveDirectory.value = '/tmp/downloads';
      expect(controller.canCreateTask, isTrue);
    },
  );

  test(
    'creates a restricted BT task with retained metadata and peers',
    () async {
      final client = _FakeEngineClient(
        btResult: _torrentResolution,
        createdBTTask: _task(
          DownloadTaskState.downloading,
          protocol: DownloadProtocol.bt,
        ),
      );
      addTearDown(client.close);
      final controller = CreateDownloadController(
        client: client,
        directoryPicker: const StubDirectoryPicker(result: '/tmp/downloads'),
        torrentFilePicker: const StubTorrentFilePicker(
          result: PickedTorrentFile(
            name: 'archive.torrent',
            bytes: <int>[1, 2, 3],
          ),
        ),
      );
      controller.onInit();
      addTearDown(controller.onClose);

      await controller.chooseTorrentFile();
      await controller.chooseSaveDirectory();
      controller.toggleBTFile(1);
      controller.explicitPeersController.text = '8.8.8.8:6881\n1.1.1.1:51413';

      expect(controller.canCreateBTTask, isTrue);
      await controller.createBTTask();

      expect(controller.phase.value, CreateDownloadPhase.downloading);
      expect(client.createdBTMetadata, <int>[1, 2, 3]);
      expect(client.createdBTFileIndexes, <int>[0]);
      expect(client.createdBTPeers, <String>['8.8.8.8:6881', '1.1.1.1:51413']);
      expect(client.createdDirectory, '/tmp/downloads');
    },
  );

  test('requires BT files, directory, and allowed public peers', () async {
    final client = _FakeEngineClient(btResult: _torrentResolution);
    final controller = CreateDownloadController(
      client: client,
      directoryPicker: const StubDirectoryPicker(),
      torrentFilePicker: const StubTorrentFilePicker(
        result: PickedTorrentFile(
          name: 'archive.torrent',
          bytes: <int>[1, 2, 3],
        ),
      ),
    );
    controller.onInit();
    addTearDown(controller.onClose);

    await controller.chooseTorrentFile();
    expect(controller.canCreateBTTask, isFalse);

    controller.saveDirectory.value = '/tmp/downloads';
    controller.explicitPeersController.text = '127.0.0.1:6881';
    expect(controller.peerInputError.value, isNotNull);
    expect(controller.canCreateBTTask, isFalse);

    controller.explicitPeersController.text = '8.8.8.8:6881';
    expect(controller.canCreateBTTask, isTrue);
    controller.toggleAllBTFiles();
    expect(controller.canCreateBTTask, isFalse);
  });

  test('keeps Magnet identity parsing non-downloadable', () async {
    final client = _FakeEngineClient(btResult: _magnetResolution);
    final controller = CreateDownloadController(
      client: client,
      directoryPicker: const StubDirectoryPicker(),
    );
    controller.onInit();
    addTearDown(controller.onClose);
    controller.urlController.text =
        'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567';

    await controller.resolve();
    controller.saveDirectory.value = '/tmp/downloads';
    controller.explicitPeersController.text = '8.8.8.8:6881';

    expect(controller.canCreateBTTask, isFalse);
  });

  test('creates a task and applies live completion events', () async {
    final client = _FakeEngineClient(
      result: _resolution,
      createdTask: _task(DownloadTaskState.downloading),
    );
    addTearDown(client.close);
    final controller = CreateDownloadController(
      client: client,
      directoryPicker: const StubDirectoryPicker(result: '/tmp/downloads'),
    );
    controller.onInit();
    addTearDown(controller.onClose);
    controller.urlController.text = _resolution.url;
    await controller.resolve();
    await controller.chooseSaveDirectory();

    await controller.createTask();

    expect(controller.phase.value, CreateDownloadPhase.downloading);
    expect(controller.task.value?.id, 'task-1');
    expect(client.createdDirectory, '/tmp/downloads');
    expect(client.createdExpectedSize, _resolution.size);
    expect(client.createdAcceptRanges, isTrue);
    expect(client.createdETag, _resolution.etag);
    expect(client.createdLastModified, _resolution.lastModified);

    client.emit(
      DownloadTaskEvent(
        type: 'task.updated',
        task: _task(DownloadTaskState.completed, downloaded: 1024, total: 1024),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.phase.value, CreateDownloadPhase.completed);
    expect(controller.task.value?.downloaded, 1024);
  });

  test('passes an HTTP schedule to the engine', () async {
    final client = _FakeEngineClient(
      result: _resolution,
      createdTask: _task(DownloadTaskState.queued),
    );
    addTearDown(client.close);
    final controller = CreateDownloadController(
      client: client,
      directoryPicker: const StubDirectoryPicker(result: '/tmp/downloads'),
    );
    controller.onInit();
    addTearDown(controller.onClose);
    controller.urlController.text = _resolution.url;
    await controller.resolve();
    await controller.chooseSaveDirectory();
    final scheduledAt = DateTime.now().add(const Duration(hours: 2));
    expect(controller.setScheduledAt(scheduledAt), isTrue);

    await controller.createTask();

    expect(client.createdScheduledAt, scheduledAt.toUtc());
  });

  test(
    'uses the engine default directory without opening the picker',
    () async {
      final client = _FakeEngineClient(
        result: _resolution,
        createdTask: _task(DownloadTaskState.downloading),
      );
      addTearDown(client.close);
      final settings = EngineSettingsService(
        client: const _SettingsEngineClient(),
      );
      await settings.load();
      final controller = CreateDownloadController(
        client: client,
        directoryPicker: const StubDirectoryPicker(),
        engineSettingsService: settings,
      );
      controller.onInit();
      addTearDown(controller.onClose);
      controller.urlController.text = _resolution.url;

      await controller.resolve();
      await controller.createTask();

      expect(controller.phase.value, CreateDownloadPhase.downloading);
      expect(client.createdDirectory, '/tmp/Downloads');
    },
  );

  test('cancels a queued task through the engine', () async {
    final client = _FakeEngineClient(
      result: _resolution,
      createdTask: _task(DownloadTaskState.queued),
      canceledTask: _task(DownloadTaskState.canceled),
    );
    addTearDown(client.close);
    final controller = CreateDownloadController(
      client: client,
      directoryPicker: const StubDirectoryPicker(result: '/tmp/downloads'),
    );
    controller.onInit();
    addTearDown(controller.onClose);
    controller.urlController.text = _resolution.url;
    await controller.resolve();
    await controller.chooseSaveDirectory();
    await controller.createTask();

    await controller.cancelTask();

    expect(controller.phase.value, CreateDownloadPhase.canceled);
    expect(client.cancelCalls, 1);
  });

  test('pauses and resumes a BT task through the shared lifecycle', () async {
    final client = _FakeEngineClient(
      btResult: _torrentResolution,
      createdBTTask: _task(
        DownloadTaskState.downloading,
        protocol: DownloadProtocol.bt,
      ),
      pausedTask: _task(
        DownloadTaskState.paused,
        protocol: DownloadProtocol.bt,
      ),
      resumedTask: _task(
        DownloadTaskState.downloading,
        protocol: DownloadProtocol.bt,
      ),
    );
    addTearDown(client.close);
    final controller = CreateDownloadController(
      client: client,
      directoryPicker: const StubDirectoryPicker(result: '/tmp/downloads'),
      torrentFilePicker: const StubTorrentFilePicker(
        result: PickedTorrentFile(
          name: 'archive.torrent',
          bytes: <int>[1, 2, 3],
        ),
      ),
    );
    controller.onInit();
    addTearDown(controller.onClose);
    await controller.chooseTorrentFile();
    await controller.chooseSaveDirectory();
    controller.explicitPeersController.text = '8.8.8.8:6881';
    await controller.createBTTask();

    await controller.pauseTask();
    expect(controller.phase.value, CreateDownloadPhase.paused);
    expect(client.pauseCalls, 1);

    await controller.resumeTask();
    expect(controller.phase.value, CreateDownloadPhase.downloading);
    expect(client.resumeCalls, 1);
  });

  test(
    'deduplicates multiline URLs and reports partial batch creation',
    () async {
      final client = _BatchEngineClient();
      final controller = CreateDownloadController(
        client: client,
        directoryPicker: const StubDirectoryPicker(result: '/tmp/downloads'),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      controller.urlController.text = [
        'https://example.com/one.zip',
        'https://example.com/one.zip',
        'ftp://example.com/not-supported.zip',
        'https://example.com/two.zip',
      ].join('\n');

      await controller.resolve();

      expect(controller.phase.value, CreateDownloadPhase.resolved);
      expect(controller.sourceUrls, hasLength(3));
      expect(controller.resolutions, hasLength(2));
      expect(controller.resolveFailures.single.url, contains('ftp://'));
      expect(client.resolveCalls, 2);

      await controller.chooseSaveDirectory();
      await controller.createTask();

      expect(controller.phase.value, CreateDownloadPhase.batchCreated);
      expect(client.createdInputs.map((item) => item.fileName), <String>[
        'one.zip',
        'two.zip',
      ]);
      expect(controller.createdTasks, hasLength(1));
      expect(controller.batchCreationFailures.single.fileName, 'two.zip');
    },
  );
}

const _resolution = DownloadResolution(
  url: 'https://example.com/file.zip',
  finalUrl: 'https://cdn.example.com/file.zip',
  fileName: 'file.zip',
  size: 1572864,
  contentType: 'application/zip',
  acceptRanges: true,
  etag: '"release-v1"',
  lastModified: 'Tue, 11 Aug 2026 01:02:03 GMT',
);

class _SettingsEngineClient extends StubEngineClient {
  const _SettingsEngineClient();

  @override
  Future<EngineSettings> fetchSettings() async => const EngineSettings(
    defaultDownloadDirectory: '/tmp/Downloads',
    fileConflictPolicy: FileConflictPolicy.fail,
    scheduler: _testScheduler,
    bitTorrent: _testBTPolicy,
  );
}

const _testScheduler = SchedulerSettings(
  maxConcurrentTasks: 3,
  downloadRateLimit: 0,
  maxRetries: 2,
);

const _magnetResolution = BTResolution(
  sourceType: BTSourceType.magnet,
  name: 'Downpeed Archive',
  infoHash: '0123456789abcdef0123456789abcdef01234567',
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
  infoHash: '0123456789abcdef0123456789abcdef01234567',
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
  _FakeEngineClient({
    this.result,
    this.error,
    this.createdTask,
    this.canceledTask,
    this.btResult,
    this.createdBTTask,
    this.pausedTask,
    this.resumedTask,
  });

  final DownloadResolution? result;
  final EngineClientException? error;
  final DownloadTask? createdTask;
  final DownloadTask? canceledTask;
  final BTResolution? btResult;
  final DownloadTask? createdBTTask;
  final DownloadTask? pausedTask;
  final DownloadTask? resumedTask;
  final _events = StreamController<DownloadTaskEvent>.broadcast();
  int resolveCalls = 0;
  int cancelCalls = 0;
  int resolveMagnetCalls = 0;
  int resolveTorrentCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  String? createdDirectory;
  int? createdExpectedSize;
  bool? createdAcceptRanges;
  String? createdETag;
  String? createdLastModified;
  DateTime? createdScheduledAt;
  List<int>? createdBTMetadata;
  List<int>? createdBTFileIndexes;
  List<String>? createdBTPeers;

  @override
  Future<EngineInfo> fetchInfo() => throw UnimplementedError();

  @override
  Future<DownloadResolution> resolveDownload(String url) async {
    resolveCalls++;
    if (error case final error?) throw error;
    return result!;
  }

  @override
  Future<BTResolution> resolveMagnet(String magnet) async {
    resolveMagnetCalls++;
    return btResult!;
  }

  @override
  Future<BTResolution> resolveTorrent(List<int> bytes) async {
    resolveTorrentCalls++;
    return btResult!;
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
    DateTime? scheduledAt,
  }) async {
    createdDirectory = saveDirectory;
    createdExpectedSize = expectedSize;
    createdAcceptRanges = acceptRanges;
    createdETag = etag;
    createdLastModified = lastModified;
    createdScheduledAt = scheduledAt;
    return createdTask!;
  }

  @override
  Future<DownloadTask> createBTTask({
    required List<int> metadata,
    required String saveDirectory,
    required List<int> selectedFileIndexes,
    required List<String> explicitPeers,
  }) async {
    createdBTMetadata = metadata;
    createdDirectory = saveDirectory;
    createdBTFileIndexes = selectedFileIndexes;
    createdBTPeers = explicitPeers;
    return createdBTTask!;
  }

  @override
  Future<DownloadTask> cancelTask(String id) async {
    cancelCalls++;
    return canceledTask!;
  }

  @override
  Future<DownloadTask> pauseTask(String id) async {
    pauseCalls++;
    return pausedTask!;
  }

  @override
  Future<DownloadTask> resumeTask(String id) async {
    resumeCalls++;
    return resumedTask!;
  }

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => _events.stream;

  void emit(DownloadTaskEvent event) => _events.add(event);

  Future<void> close() => _events.close();
}

class _BatchEngineClient extends StubEngineClient {
  int resolveCalls = 0;
  List<CreateTaskInput> createdInputs = const <CreateTaskInput>[];

  @override
  Future<DownloadResolution> resolveDownload(String url) async {
    resolveCalls++;
    final fileName = Uri.parse(url).pathSegments.last;
    return DownloadResolution(
      url: url,
      finalUrl: url,
      fileName: fileName,
      size: 1024,
      contentType: 'application/zip',
      acceptRanges: true,
    );
  }

  @override
  Future<BatchTaskResult> createTasks(List<CreateTaskInput> tasks) async {
    createdInputs = tasks;
    return BatchTaskResult(
      items: <BatchTaskItemResult>[
        BatchTaskItemResult(
          index: 0,
          id: 'task-1',
          task: _task(DownloadTaskState.queued),
        ),
        const BatchTaskItemResult(
          index: 1,
          error: BatchTaskError(
            code: 'destination_exists',
            message: 'exists',
            retryable: false,
          ),
        ),
      ],
      succeeded: 1,
      failed: 1,
    );
  }
}

DownloadTask _task(
  DownloadTaskState state, {
  int downloaded = 0,
  int total = 1024,
  DownloadProtocol protocol = DownloadProtocol.http,
}) {
  final now = DateTime.utc(2026, 8, 11);
  return DownloadTask(
    id: 'task-1',
    url: _resolution.url,
    finalUrl: _resolution.finalUrl,
    fileName: _resolution.fileName,
    saveDirectory: '/tmp/downloads',
    filePath: '/tmp/downloads/file.zip',
    state: state,
    downloaded: downloaded,
    total: total,
    speedBps: state == DownloadTaskState.downloading ? 512 : 0,
    protocol: protocol,
    connections: protocol == DownloadProtocol.bt ? 2 : 0,
    createdAt: now,
    updatedAt: now,
    completedAt:
        state == DownloadTaskState.completed ||
            state == DownloadTaskState.failed ||
            state == DownloadTaskState.canceled
        ? now
        : null,
  );
}
