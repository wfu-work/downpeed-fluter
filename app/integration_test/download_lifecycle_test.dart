import 'dart:io';
import 'dart:typed_data';

import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/services/embedded_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'embedded engine downloads, pauses, resumes, and restores a task',
    (tester) async {
      final workspace = await Directory.systemTemp.createTemp(
        'downpeed-integration-',
      );
      final dataDirectory = Directory('${workspace.path}/data');
      final downloadDirectory = Directory('${workspace.path}/downloads');
      await dataDirectory.create(recursive: true);
      await downloadDirectory.create(recursive: true);

      final fixture = await _RangeFixture.start();
      final enginePort = await _reserveLoopbackPort();
      final address = '127.0.0.1:$enginePort';
      final configuration = <String, Object?>{
        'address': address,
        'dataDir': dataDirectory.path,
        'defaultDownloadDirectory': downloadDirectory.path,
        'maxConcurrentTasks': 1,
        'maxRetries': 0,
      };
      final host = FfiEngineLifecycleHost.open();
      var engineRunning = false;

      addTearDown(() async {
        if (engineRunning) await host.stop();
        await fixture.close();
        await workspace.delete(recursive: true);
      });

      await host.start(configuration);
      engineRunning = true;
      final client = DioEngineClient(baseUrl: 'http://$address');
      final info = await client.fetchInfo();
      expect(info.apiVersion, 'v1');

      final resolution = await client.resolveDownload(fixture.uri.toString());
      expect(resolution.size, fixture.payload.length);
      expect(resolution.acceptRanges, isTrue);
      expect(resolution.etag, _RangeFixture.etag);

      final created = await client.createTask(
        url: resolution.url,
        fileName: resolution.fileName,
        saveDirectory: downloadDirectory.path,
        expectedSize: resolution.size,
        acceptRanges: resolution.acceptRanges,
        etag: resolution.etag,
        lastModified: resolution.lastModified,
      );
      final active = await _waitForTask(
        client,
        created.id,
        (task) =>
            task.state == DownloadTaskState.downloading &&
            task.downloaded > 0 &&
            task.downloaded < task.total,
      );
      expect(active.downloaded, greaterThan(0));

      final paused = await client.pauseTask(created.id);
      expect(paused.state, DownloadTaskState.paused);
      expect(paused.downloaded, greaterThan(0));
      expect(File(paused.filePath).existsSync(), isFalse);

      await host.stop();
      engineRunning = false;
      await host.start(configuration);
      engineRunning = true;
      final restored = await client.fetchTask(created.id);
      expect(restored.state, DownloadTaskState.paused);
      expect(restored.downloaded, paused.downloaded);

      await client.resumeTask(created.id);
      final completed = await _waitForTask(
        client,
        created.id,
        (task) => task.state == DownloadTaskState.completed,
      );
      expect(completed.downloaded, fixture.payload.length);
      expect(completed.total, fixture.payload.length);
      final downloaded = await File(completed.filePath).readAsBytes();
      expect(_sameBytes(downloaded, fixture.payload), isTrue);

      await host.stop();
      engineRunning = false;
      await host.start(configuration);
      engineRunning = true;
      final completedAfterRestart = await client.fetchTask(created.id);
      expect(completedAfterRestart.state, DownloadTaskState.completed);
      expect(completedAfterRestart.downloaded, fixture.payload.length);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<DownloadTask> _waitForTask(
  EngineClient client,
  String id,
  bool Function(DownloadTask task) predicate,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  DownloadTask? latest;
  while (DateTime.now().isBefore(deadline)) {
    latest = await client.fetchTask(id);
    if (predicate(latest)) return latest;
    if (latest.state == DownloadTaskState.failed ||
        latest.state == DownloadTaskState.canceled) {
      fail(
        'Task entered ${latest.state.name}: '
        '${latest.error?.code ?? 'no error code'}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for task $id; latest state: ${latest?.state.name}');
}

Future<int> _reserveLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class _RangeFixture {
  _RangeFixture._(this.server, this.payload);

  static const etag = '"downpeed-integration-v1"';
  static const _chunkSize = 16 * 1024;
  static const _chunkDelay = Duration(milliseconds: 6);

  final HttpServer server;
  final Uint8List payload;

  Uri get uri => Uri.parse(
    'http://${server.address.address}:${server.port}/integration-fixture.bin',
  );

  static Future<_RangeFixture> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final payload = Uint8List(8 * 1024 * 1024);
    for (var index = 0; index < payload.length; index++) {
      payload[index] = (index * 31 + 17) & 0xff;
    }
    final fixture = _RangeFixture._(server, payload);
    server.listen(fixture._handleRequest);
    return fixture;
  }

  Future<void> close() => server.close(force: true);

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..contentType = ContentType.binary
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.etagHeader, etag)
      ..set(
        'content-disposition',
        'attachment; filename="integration-fixture.bin"',
      );
    if (request.method == 'HEAD') {
      response.contentLength = payload.length;
      await response.close();
      return;
    }
    if (request.method != 'GET') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }

    final range = _parseRange(request.headers.value(HttpHeaders.rangeHeader));
    final start = range?.$1 ?? 0;
    final end = range?.$2 ?? payload.length - 1;
    if (start < 0 || start >= payload.length || end < start) {
      response
        ..statusCode = HttpStatus.requestedRangeNotSatisfiable
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */${payload.length}',
        );
      await response.close();
      return;
    }
    final boundedEnd = end.clamp(start, payload.length - 1);
    if (range != null) {
      response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$boundedEnd/${payload.length}',
        );
    }
    response.contentLength = boundedEnd - start + 1;
    try {
      for (var offset = start; offset <= boundedEnd; offset += _chunkSize) {
        final chunkEnd = (offset + _chunkSize).clamp(offset, boundedEnd + 1);
        response.add(Uint8List.sublistView(payload, offset, chunkEnd));
        await response.flush();
        await Future<void>.delayed(_chunkDelay);
      }
      await response.close();
    } on Object {
      // Pausing a task closes active range requests by design.
    }
  }

  (int, int)? _parseRange(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(value.trim());
    if (match == null) return null;
    final start = int.tryParse(match.group(1)!);
    final endText = match.group(2)!;
    final end = endText.isEmpty ? payload.length - 1 : int.tryParse(endText);
    if (start == null || end == null) return null;
    return (start, end);
  }
}
