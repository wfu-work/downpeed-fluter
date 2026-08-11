import 'dart:convert';
import 'dart:io';

import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/batch_task_result.dart';
import 'package:downpeed_flutter/domains/download_resolution.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses queued and retrying scheduler states', () {
    final queued = DownloadTask.fromJson(<String, dynamic>{
      ..._eventJson['task'] as Map,
      'state': 'queued',
      'speedBps': 0,
    });
    final retrying = DownloadTask.fromJson(<String, dynamic>{
      ..._eventJson['task'] as Map,
      'state': 'retrying',
      'speedBps': 0,
      'retryCount': 2,
      'nextRetryAt': '2026-08-11T01:00:05Z',
    });

    expect(queued.state, DownloadTaskState.queued);
    expect(queued.canPause, isTrue);
    expect(retrying.state, DownloadTaskState.retrying);
    expect(retrying.retryCount, 2);
    expect(retrying.nextRetryAt, DateTime.utc(2026, 8, 11, 1, 0, 5));
    expect(retrying.canCancel, isTrue);
  });

  test('parses optional HTTP resource validators', () {
    final resolution = DownloadResolution.fromJson(<String, dynamic>{
      'url': 'https://example.com/file.bin',
      'finalUrl': 'https://cdn.example.com/file.bin',
      'fileName': 'file.bin',
      'size': 1024,
      'contentType': 'application/octet-stream',
      'acceptRanges': true,
      'etag': '"release-v1"',
      'lastModified': 'Tue, 11 Aug 2026 01:02:03 GMT',
    });

    expect(resolution.etag, '"release-v1"');
    expect(resolution.lastModified, 'Tue, 11 Aug 2026 01:02:03 GMT');
  });

  test(
    'sends resolved size and Range capability when creating a task',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      Map<String, dynamic>? requestBody;
      server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/tasks');
        requestBody = Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join()) as Map,
        );
        request.response
          ..statusCode = HttpStatus.created
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, dynamic>{
              'data': _eventJson['task'],
              'error': null,
              'requestId': 'create-task',
            }),
          );
        await request.response.close();
      });
      final client = DioEngineClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
      );

      await client.createTask(
        url: 'https://example.com/file.bin',
        fileName: 'file.bin',
        saveDirectory: '/tmp/downloads',
        expectedSize: 1024,
        acceptRanges: true,
        etag: '"release-v1"',
        lastModified: 'Tue, 11 Aug 2026 01:02:03 GMT',
      );

      expect(requestBody, <String, dynamic>{
        'url': 'https://example.com/file.bin',
        'fileName': 'file.bin',
        'saveDirectory': '/tmp/downloads',
        'expectedSize': 1024,
        'acceptRanges': true,
        'etag': '"release-v1"',
        'lastModified': 'Tue, 11 Aug 2026 01:02:03 GMT',
      });
    },
  );

  test('parses task updates from the engine SSE stream', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.uri.path, '/api/v1/events');
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        )
        ..write('event: task.updated\n')
        ..write('data: ${jsonEncode(_eventJson)}\n\n');
      await request.response.close();
    });
    final client = DioEngineClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );

    final event = await client.watchTaskEvents().first;

    expect(event.type, 'task.updated');
    expect(event.task.id, 'task-sse');
    expect(event.task.state, DownloadTaskState.downloading);
    expect(event.task.downloaded, 512);
  });

  test('uses the pause and resume task REST actions', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final paths = <String>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      expect(request.method, 'PUT');
      final state = request.uri.path.endsWith('/pause')
          ? 'paused'
          : 'downloading';
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              ..._eventJson['task'] as Map,
              'state': state,
            },
            'error': null,
            'requestId': 'task-action',
          }),
        );
      await request.response.close();
    });
    final client = DioEngineClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );

    final paused = await client.pauseTask('task-sse');
    final resumed = await client.resumeTask('task-sse');

    expect(paused.state, DownloadTaskState.paused);
    expect(resumed.state, DownloadTaskState.downloading);
    expect(paths, <String>[
      '/api/v1/tasks/task-sse/pause',
      '/api/v1/tasks/task-sse/resume',
    ]);
  });

  test('uses bounded batch contracts and parses per-item failures', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <Map<String, dynamic>>[];
    server.listen((request) async {
      requests.add(<String, dynamic>{
        'path': request.uri.path,
        'body': jsonDecode(await utf8.decoder.bind(request).join()),
      });
      final creating = request.uri.path.endsWith('/batch');
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, dynamic>{
            'data': creating
                ? <String, dynamic>{
                    'items': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'index': 0,
                        'id': 'task-sse',
                        'task': _eventJson['task'],
                      },
                      <String, dynamic>{
                        'index': 1,
                        'error': <String, dynamic>{
                          'code': 'destination_exists',
                          'message': 'Destination exists.',
                          'retryable': false,
                        },
                      },
                    ],
                    'succeeded': 1,
                    'failed': 1,
                  }
                : <String, dynamic>{
                    'items': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'index': 0,
                        'id': 'task-sse',
                        'task': <String, dynamic>{
                          ..._eventJson['task'] as Map,
                          'state': 'paused',
                          'speedBps': 0,
                        },
                      },
                    ],
                    'succeeded': 1,
                    'failed': 0,
                  },
            'error': null,
            'requestId': 'batch-task',
          }),
        );
      await request.response.close();
    });
    final client = DioEngineClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );

    final created = await client.createTasks(const <CreateTaskInput>[
      CreateTaskInput(
        url: 'https://example.com/one.bin',
        fileName: 'one.bin',
        saveDirectory: '/tmp/downloads',
      ),
      CreateTaskInput(
        url: 'https://example.com/two.bin',
        fileName: 'two.bin',
        saveDirectory: '/tmp/downloads',
      ),
    ]);
    final acted = await client.actOnTasks(const <String>[
      'task-sse',
    ], BatchTaskAction.pause);

    expect(created.succeeded, 1);
    expect(created.items[1].error?.code, 'destination_exists');
    expect(acted.successfulTasks.single.state, DownloadTaskState.paused);
    expect(requests[0]['path'], '/api/v1/tasks/batch');
    expect(requests[1], <String, dynamic>{
      'path': '/api/v1/tasks/batch/actions',
      'body': <String, dynamic>{
        'ids': <String>['task-sse'],
        'action': 'pause',
      },
    });
  });
}

final _eventJson = <String, dynamic>{
  'type': 'task.updated',
  'task': <String, dynamic>{
    'id': 'task-sse',
    'url': 'https://example.com/file.bin',
    'finalUrl': 'https://cdn.example.com/file.bin',
    'fileName': 'file.bin',
    'saveDirectory': '/tmp/downloads',
    'filePath': '/tmp/downloads/file.bin',
    'state': 'downloading',
    'downloaded': 512,
    'total': 1024,
    'speedBps': 256,
    'createdAt': '2026-08-11T01:00:00Z',
    'updatedAt': '2026-08-11T01:00:01Z',
  },
};
