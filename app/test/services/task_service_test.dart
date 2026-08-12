import 'dart:async';

import 'package:downpeed_flutter/domains/batch_task_result.dart';
import 'package:downpeed_flutter/domains/delete_task_result.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/services/task_service.dart';
import 'package:downpeed_flutter/services/desktop_actions_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stub_engine_client.dart';

void main() {
  test('loads tasks and reconciles SSE updates', () async {
    final client = _TaskEngineClient([_task(DownloadTaskState.downloading)]);
    addTearDown(client.close);
    final service = TaskService(
      client: client,
      desktopActions: _desktopActions(),
    );
    addTearDown(service.onClose);

    await service.start();
    expect(service.tasks.single.downloaded, 256);

    client.emit(_task(DownloadTaskState.paused, downloaded: 512));
    await Future<void>.delayed(Duration.zero);

    expect(service.tasks.single.state, DownloadTaskState.paused);
    expect(service.tasks.single.downloaded, 512);
  });

  test('pause and resume actions apply only engine-returned state', () async {
    final client = _TaskEngineClient([_task(DownloadTaskState.downloading)]);
    addTearDown(client.close);
    final service = TaskService(
      client: client,
      desktopActions: _desktopActions(),
    );
    addTearDown(service.onClose);
    await service.start();

    await service.pause('task-1');
    expect(service.tasks.single.state, DownloadTaskState.paused);
    expect(client.pauseCalls, 1);

    await service.resume('task-1');
    expect(service.tasks.single.state, DownloadTaskState.downloading);
    expect(client.resumeCalls, 1);
  });

  test(
    'batch actions reconcile successes and preserve item failures',
    () async {
      final client = _TaskEngineClient([_task(DownloadTaskState.downloading)]);
      addTearDown(client.close);
      final service = TaskService(
        client: client,
        desktopActions: _desktopActions(),
      );
      addTearDown(service.onClose);
      await service.start();

      final result = await service.actOnTasks(const <String>[
        'task-1',
        'missing',
      ], BatchTaskAction.pause);

      expect(client.batchCalls, 1);
      expect(result?.failed, 1);
      expect(service.tasks.single.state, DownloadTaskState.paused);
      expect(service.actionTaskIds, isEmpty);
    },
  );

  test('notifies once only when an observed task becomes completed', () async {
    final client = _TaskEngineClient([_task(DownloadTaskState.completed)]);
    addTearDown(client.close);
    final platform = _RecordingDesktopActions();
    final service = TaskService(
      client: client,
      desktopActions: DesktopActionsService(platform: platform),
    );
    addTearDown(service.onClose);

    await service.start();
    expect(platform.notifications, isEmpty);

    client.emit(_task(DownloadTaskState.downloading, downloaded: 512));
    client.emit(_task(DownloadTaskState.completed, downloaded: 1024));
    client.emit(_task(DownloadTaskState.completed, downloaded: 1024));
    await Future<void>.delayed(Duration.zero);

    expect(platform.notifications, <String>['task-1']);
  });

  test('deletes a task only after the engine confirms removal', () async {
    final client = _TaskEngineClient([_task(DownloadTaskState.completed)]);
    addTearDown(client.close);
    final service = TaskService(
      client: client,
      desktopActions: _desktopActions(),
    );
    addTearDown(service.onClose);
    await service.start();

    final result = await service.deleteTask('task-1', deleteFile: true);

    expect(result?.fileDeleted, isTrue);
    expect(client.deleteCalls, 1);
    expect(client.lastDeleteFile, isTrue);
    expect(service.tasks, isEmpty);
  });

  test('batch deletion removes successes and preserves failed tasks', () async {
    final client = _TaskEngineClient([
      _task(DownloadTaskState.completed, id: 'completed'),
      _task(DownloadTaskState.failed, id: 'failed'),
    ]);
    addTearDown(client.close);
    final service = TaskService(
      client: client,
      desktopActions: _desktopActions(),
    );
    addTearDown(service.onClose);
    await service.start();

    final result = await service.deleteTasks(const <String>[
      'completed',
      'failed',
    ]);

    expect(result?.succeeded, 1);
    expect(result?.failed, 1);
    expect(service.tasks.map((task) => task.id), <String>['failed']);
    expect(service.actionTaskIds, isEmpty);
  });

  test('task.removed events reconcile records deleted elsewhere', () async {
    final client = _TaskEngineClient([_task(DownloadTaskState.completed)]);
    addTearDown(client.close);
    final service = TaskService(
      client: client,
      desktopActions: _desktopActions(),
    );
    addTearDown(service.onClose);
    await service.start();

    client.emitRemoved(_task(DownloadTaskState.completed));
    await Future<void>.delayed(Duration.zero);

    expect(service.tasks, isEmpty);
  });
}

DesktopActionsService _desktopActions() =>
    DesktopActionsService(platform: _RecordingDesktopActions());

class _RecordingDesktopActions implements DesktopActionsPlatform {
  final notifications = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<void> openFile(String path) async {}

  @override
  Future<void> revealFile(String path) async {}

  @override
  Future<void> showCompletionNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    notifications.add(id);
  }
}

class _TaskEngineClient extends StubEngineClient {
  _TaskEngineClient(this.initialTasks);

  final List<DownloadTask> initialTasks;
  final _events = StreamController<DownloadTaskEvent>.broadcast();
  int pauseCalls = 0;
  int resumeCalls = 0;
  int batchCalls = 0;
  int deleteCalls = 0;
  bool? lastDeleteFile;

  @override
  Future<List<DownloadTask>> fetchTasks() async => initialTasks;

  @override
  Future<DownloadTask> pauseTask(String id) async {
    pauseCalls++;
    return _task(DownloadTaskState.paused, downloaded: 512);
  }

  @override
  Future<DownloadTask> resumeTask(String id) async {
    resumeCalls++;
    return _task(DownloadTaskState.downloading, downloaded: 512);
  }

  @override
  Future<BatchTaskResult> actOnTasks(
    List<String> ids,
    BatchTaskAction action,
  ) async {
    batchCalls++;
    return BatchTaskResult(
      items: <BatchTaskItemResult>[
        BatchTaskItemResult(
          index: 0,
          id: ids.first,
          task: _task(DownloadTaskState.paused, downloaded: 512),
        ),
        const BatchTaskItemResult(
          index: 1,
          id: 'missing',
          error: BatchTaskError(
            code: 'task_not_found',
            message: 'missing',
            retryable: false,
          ),
        ),
      ],
      succeeded: 1,
      failed: 1,
    );
  }

  @override
  Future<DeleteTaskResult> deleteTask(
    String id, {
    bool deleteFile = false,
  }) async {
    deleteCalls++;
    lastDeleteFile = deleteFile;
    return DeleteTaskResult(id: id, fileDeleted: deleteFile);
  }

  @override
  Future<BatchDeleteTaskResult> deleteTasks(
    List<String> ids, {
    bool deleteFiles = false,
  }) async {
    return BatchDeleteTaskResult(
      items: <BatchDeleteTaskItemResult>[
        BatchDeleteTaskItemResult(
          index: 0,
          id: ids.first,
          fileDeleted: deleteFiles,
        ),
        BatchDeleteTaskItemResult(
          index: 1,
          id: ids.last,
          fileDeleted: false,
          error: const BatchTaskError(
            code: 'task_operation_failed',
            message: 'failed',
            retryable: true,
          ),
        ),
      ],
      succeeded: 1,
      failed: 1,
    );
  }

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => _events.stream;

  void emit(DownloadTask task) {
    _events.add(DownloadTaskEvent(type: 'task.updated', task: task));
  }

  void emitRemoved(DownloadTask task) {
    _events.add(DownloadTaskEvent(type: 'task.removed', task: task));
  }

  Future<void> close() => _events.close();
}

DownloadTask _task(
  DownloadTaskState state, {
  int downloaded = 256,
  String id = 'task-1',
}) {
  final now = DateTime.utc(2026, 8, 11, 1);
  return DownloadTask(
    id: id,
    url: 'https://example.com/archive.zip',
    finalUrl: 'https://cdn.example.com/archive.zip',
    fileName: 'archive.zip',
    saveDirectory: '/tmp/downloads',
    filePath: '/tmp/downloads/archive.zip',
    state: state,
    downloaded: downloaded,
    total: 1024,
    speedBps: state == DownloadTaskState.downloading ? 128 : 0,
    createdAt: now,
    updatedAt: now,
  );
}
