import 'dart:async';

import 'package:downpeed_flutter/app/pages/create_download/create_download_controller.dart';
import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/batch_task_result.dart';
import 'package:downpeed_flutter/domains/download_resolution.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stub_directory_picker.dart';
import '../support/stub_engine_client.dart';

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

class _FakeEngineClient extends StubEngineClient {
  _FakeEngineClient({
    this.result,
    this.error,
    this.createdTask,
    this.canceledTask,
  });

  final DownloadResolution? result;
  final EngineClientException? error;
  final DownloadTask? createdTask;
  final DownloadTask? canceledTask;
  final _events = StreamController<DownloadTaskEvent>.broadcast();
  int resolveCalls = 0;
  int cancelCalls = 0;
  String? createdDirectory;
  int? createdExpectedSize;
  bool? createdAcceptRanges;
  String? createdETag;
  String? createdLastModified;

  @override
  Future<EngineInfo> fetchInfo() => throw UnimplementedError();

  @override
  Future<DownloadResolution> resolveDownload(String url) async {
    resolveCalls++;
    if (error case final error?) throw error;
    return result!;
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
    createdDirectory = saveDirectory;
    createdExpectedSize = expectedSize;
    createdAcceptRanges = acceptRanges;
    createdETag = etag;
    createdLastModified = lastModified;
    return createdTask!;
  }

  @override
  Future<DownloadTask> cancelTask(String id) async {
    cancelCalls++;
    return canceledTask!;
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
