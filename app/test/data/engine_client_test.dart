import 'dart:convert';
import 'dart:io';

import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/batch_task_result.dart';
import 'package:downpeed_flutter/domains/bt_diagnostics.dart';
import 'package:downpeed_flutter/domains/bt_resolution.dart';
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

  test('defaults legacy task protocol and connections to HTTP zero', () {
    final task = DownloadTask.fromJson(
      Map<String, dynamic>.from(_eventJson['task'] as Map)..remove('protocol'),
    );

    expect(task.protocol, DownloadProtocol.http);
    expect(task.connections, 0);
  });

  test('detects an unexpectedly enabled restricted BT capability', () {
    const policy = BTPolicyDiagnostics(
      maxPeerConnections: 80,
      explicitPeersOnly: true,
      trackersEnabled: true,
      dhtEnabled: false,
      pexEnabled: false,
      webSeedsEnabled: false,
      inboundEnabled: false,
      ipv6Enabled: false,
      uploadEnabled: false,
      seedingEnabled: false,
    );

    expect(policy.restrictedCapabilitiesDisabled, isFalse);
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

  test('reads and updates engine settings through the JSON API', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <Map<String, dynamic>>[];
    server.listen((request) async {
      dynamic body;
      if (request.method == 'PUT') {
        body = jsonDecode(await utf8.decoder.bind(request).join());
      }
      requests.add(<String, dynamic>{
        'method': request.method,
        'path': request.uri.path,
        'body': ?body,
      });
      final directory = request.method == 'PUT'
          ? '/tmp/downpeed-selected'
          : '/tmp/Downloads';
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'defaultDownloadDirectory': directory,
              'bitTorrent': _btPolicyJson(
                request.method == 'PUT'
                    ? ((body as Map<String, dynamic>)['bitTorrent']
                              as Map<String, dynamic>)['maxPeerConnections']
                          as int
                    : 80,
              ),
            },
            'error': null,
            'requestId': 'settings',
          }),
        );
      await request.response.close();
    });
    final client = DioEngineClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );

    final initial = await client.fetchSettings();
    final updated = await client.updateSettings(
      defaultDownloadDirectory: '/tmp/downpeed-selected',
      bitTorrent: initial.bitTorrent.copyWith(maxPeerConnections: 24),
    );

    expect(initial.defaultDownloadDirectory, '/tmp/Downloads');
    expect(updated.defaultDownloadDirectory, '/tmp/downpeed-selected');
    expect(updated.bitTorrent.maxPeerConnections, 24);
    expect(requests, <Map<String, dynamic>>[
      <String, dynamic>{'method': 'GET', 'path': '/api/v1/settings'},
      <String, dynamic>{
        'method': 'PUT',
        'path': '/api/v1/settings',
        'body': <String, dynamic>{
          'defaultDownloadDirectory': '/tmp/downpeed-selected',
          'bitTorrent': _btPolicyJson(24),
        },
      },
    ]);
  });

  test('resolves Magnet identity with the JSON API contract', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    Map<String, dynamic>? requestBody;
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/bt/resolve/magnet');
      expect(request.headers.contentType?.mimeType, ContentType.json.mimeType);
      requestBody = Map<String, dynamic>.from(
        jsonDecode(await utf8.decoder.bind(request).join()) as Map,
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(_magnetEnvelope));
      await request.response.close();
    });
    final client = DioEngineClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );

    final resolution = await client.resolveMagnet(_magnetUri);

    expect(requestBody, <String, dynamic>{'magnet': _magnetUri});
    expect(resolution.sourceType, BTSourceType.magnet);
    expect(resolution.metadataAvailable, isFalse);
    expect(resolution.infoHash, _infoHash);
    expect(
      resolution.trackers.single.displayValue,
      'https://tracker.example.com',
    );
  });

  test('sends Torrent metadata as bounded raw bytes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final metadata = <int>[0x64, 0x34, 0x3a, 0x69, 0x6e, 0x66, 0x6f, 0x65];
    List<int>? requestBody;
    String? contentType;
    int? contentLength;
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/bt/resolve/torrent');
      contentType = request.headers.contentType?.mimeType;
      contentLength = request.contentLength;
      requestBody = await request.fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(_torrentEnvelope));
      await request.response.close();
    });
    final client = DioEngineClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );

    final resolution = await client.resolveTorrent(metadata);

    expect(contentType, 'application/x-bittorrent');
    expect(contentLength, metadata.length);
    expect(requestBody, metadata);
    expect(resolution.sourceType, BTSourceType.torrent);
    expect(resolution.metadataAvailable, isTrue);
    expect(resolution.isPrivate, isTrue);
    expect(resolution.files.map((file) => file.path), <String>[
      'Downpeed Archive/one.bin',
      'Downpeed Archive/two.bin',
    ]);
    expect(resolution.totalSize, 3072);
  });

  test('creates a BT task with base64 metadata and explicit peers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    Map<String, dynamic>? requestBody;
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/bt/tasks');
      requestBody = Map<String, dynamic>.from(
        jsonDecode(await utf8.decoder.bind(request).join()) as Map,
      );
      request.response
        ..statusCode = HttpStatus.created
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              ..._eventJson['task'] as Map,
              'protocol': 'bt',
              'url': 'bt://$_infoHash',
              'finalUrl': 'bt://$_infoHash',
              'connections': 2,
            },
            'error': null,
            'requestId': 'create-bt-task',
          }),
        );
      await request.response.close();
    });
    final client = DioEngineClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );

    final task = await client.createBTTask(
      metadata: const <int>[1, 2, 3],
      saveDirectory: '/tmp/downloads',
      selectedFileIndexes: const <int>[0, 2],
      explicitPeers: const <String>['8.8.8.8:6881'],
    );

    expect(requestBody, <String, dynamic>{
      'metadata': 'AQID',
      'saveDirectory': '/tmp/downloads',
      'selectedFileIndexes': <int>[0, 2],
      'explicitPeers': <String>['8.8.8.8:6881'],
    });
    expect(task.protocol, DownloadProtocol.bt);
    expect(task.connections, 2);
  });

  test('reads sanitized BT connection diagnostics', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/v1/tasks/bt-1/bt/diagnostics');
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(_btDiagnosticsEnvelope));
      await request.response.close();
    });
    final client = DioEngineClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );

    final diagnostics = await client.fetchBTDiagnostics('bt-1');

    expect(diagnostics.live, isTrue);
    expect(diagnostics.connections.configured, 2);
    expect(diagnostics.connections.connected, 1);
    expect(diagnostics.traffic.usefulBytes, 1024);
    expect(diagnostics.traffic.uploadedBytes, 0);
    expect(diagnostics.peers.single.address, '8.8.x.x:6881');
    expect(diagnostics.policy.explicitPeersOnly, isTrue);
    expect(diagnostics.policy.maxPeerConnections, 80);
    expect(diagnostics.policy.trackersEnabled, isFalse);
    expect(diagnostics.policy.restrictedCapabilitiesDisabled, isTrue);
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

  test('uses the pause, resume and retry task REST actions', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final paths = <String>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      expect(
        request.method,
        request.uri.path.endsWith('/retry') ? 'POST' : 'PUT',
      );
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
    final retried = await client.retryTask('task-sse');

    expect(paused.state, DownloadTaskState.paused);
    expect(resumed.state, DownloadTaskState.downloading);
    expect(retried.state, DownloadTaskState.downloading);
    expect(paths, <String>[
      '/api/v1/tasks/task-sse/pause',
      '/api/v1/tasks/task-sse/resume',
      '/api/v1/tasks/task-sse/retry',
    ]);
  });

  test('uses explicit cancel and task-record deletion contracts', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <Map<String, dynamic>>[];
    server.listen((request) async {
      dynamic requestBody;
      if (request.method == 'POST') {
        requestBody = jsonDecode(await utf8.decoder.bind(request).join());
      }
      requests.add(<String, dynamic>{
        'method': request.method,
        'path': request.uri.path,
        'query': request.uri.queryParameters,
        'body': ?requestBody,
      });
      final canceling = request.uri.path.endsWith('/cancel');
      final deletingOne = request.uri.path.endsWith('/record');
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, dynamic>{
            'data': canceling
                ? <String, dynamic>{
                    ..._eventJson['task'] as Map,
                    'state': 'canceled',
                    'speedBps': 0,
                  }
                : deletingOne
                ? <String, dynamic>{'id': 'task-sse', 'fileDeleted': true}
                : <String, dynamic>{
                    'items': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'index': 0,
                        'id': 'task-sse',
                        'fileDeleted': request.uri.path.endsWith('/delete'),
                      },
                    ],
                    'succeeded': 1,
                    'failed': 0,
                  },
            'error': null,
            'requestId': 'delete-task',
          }),
        );
      await request.response.close();
    });
    final client = DioEngineClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );

    final canceled = await client.cancelTask('task-sse');
    final deleted = await client.deleteTask('task-sse', deleteFile: true);
    final batch = await client.deleteTasks(const <String>[
      'task-sse',
    ], deleteFiles: true);
    final cleared = await client.clearCompletedTasks();

    expect(canceled.state, DownloadTaskState.canceled);
    expect(deleted.fileDeleted, isTrue);
    expect(batch.succeeded, 1);
    expect(cleared.succeeded, 1);
    expect(requests, <Map<String, dynamic>>[
      <String, dynamic>{
        'method': 'PUT',
        'path': '/api/v1/tasks/task-sse/cancel',
        'query': <String, String>{},
      },
      <String, dynamic>{
        'method': 'DELETE',
        'path': '/api/v1/tasks/task-sse/record',
        'query': <String, String>{'deleteFiles': 'true'},
      },
      <String, dynamic>{
        'method': 'POST',
        'path': '/api/v1/tasks/batch/delete',
        'query': <String, String>{},
        'body': <String, dynamic>{
          'ids': <String>['task-sse'],
          'deleteFiles': true,
        },
      },
      <String, dynamic>{
        'method': 'DELETE',
        'path': '/api/v1/tasks/completed',
        'query': <String, String>{},
      },
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
    'protocol': 'http',
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

const _infoHash = '0123456789abcdef0123456789abcdef01234567';
const _magnetUri = 'magnet:?xt=urn:btih:$_infoHash';

final _magnetEnvelope = <String, dynamic>{
  'data': <String, dynamic>{
    'sourceType': 'magnet',
    'name': 'Downpeed Archive',
    'infoHash': _infoHash,
    'v2InfoHash': '',
    'metadataAvailable': false,
    'private': false,
    'totalSize': -1,
    'pieceLength': 0,
    'files': <Object>[],
    'trackers': <Map<String, dynamic>>[
      <String, dynamic>{'scheme': 'https', 'host': 'tracker.example.com'},
    ],
  },
  'error': null,
  'requestId': 'resolve-magnet',
};

final _torrentEnvelope = <String, dynamic>{
  'data': <String, dynamic>{
    'sourceType': 'torrent',
    'name': 'Downpeed Archive',
    'infoHash': _infoHash,
    'v2InfoHash': '',
    'metadataAvailable': true,
    'private': true,
    'totalSize': 3072,
    'pieceLength': 16384,
    'files': <Map<String, dynamic>>[
      <String, dynamic>{
        'index': 0,
        'path': 'Downpeed Archive/one.bin',
        'size': 1024,
      },
      <String, dynamic>{
        'index': 1,
        'path': 'Downpeed Archive/two.bin',
        'size': 2048,
      },
    ],
    'trackers': <Map<String, dynamic>>[
      <String, dynamic>{'scheme': 'https', 'host': 'tracker.example.com'},
    ],
  },
  'error': null,
  'requestId': 'resolve-torrent',
};

final _btDiagnosticsEnvelope = <String, dynamic>{
  'data': <String, dynamic>{
    'taskId': 'bt-1',
    'state': 'downloading',
    'live': true,
    'connections': <String, dynamic>{
      'configured': 2,
      'known': 2,
      'connected': 1,
      'pending': 1,
      'halfOpen': 0,
      'seeders': 1,
    },
    'traffic': <String, dynamic>{
      'receivedBytes': 1200,
      'usefulBytes': 1024,
      'uploadedBytes': 0,
      'wastedChunks': 0,
      'verifiedPieces': 1,
      'failedPieces': 0,
    },
    'peers': <Map<String, dynamic>>[
      <String, dynamic>{
        'address': '8.8.x.x:6881',
        'client': 'test-peer',
        'network': 'TCP',
        'receivedBytes': 1024,
        'downloadRateBps': 256,
        'verifiedPieces': 1,
        'failedPieces': 0,
      },
    ],
    'policy': <String, dynamic>{
      'maxPeerConnections': 80,
      'explicitPeersOnly': true,
      'trackersEnabled': false,
      'dhtEnabled': false,
      'pexEnabled': false,
      'webSeedsEnabled': false,
      'inboundEnabled': false,
      'ipv6Enabled': false,
      'uploadEnabled': false,
      'seedingEnabled': false,
    },
    'updatedAt': '2026-08-12T03:00:00Z',
  },
  'error': null,
  'requestId': 'bt-diagnostics',
};

Map<String, dynamic> _btPolicyJson(int maxPeerConnections) => <String, dynamic>{
  'maxPeerConnections': maxPeerConnections,
  'explicitPeersOnly': true,
  'trackersEnabled': false,
  'dhtEnabled': false,
  'pexEnabled': false,
  'webSeedsEnabled': false,
  'inboundEnabled': false,
  'ipv6Enabled': false,
  'uploadEnabled': false,
  'seedingEnabled': false,
};
