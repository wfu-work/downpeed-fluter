import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<void> main(List<String> arguments) async {
  final executable = _argument(arguments, '--executable');
  final executableFile = File(executable);
  if (!executableFile.existsSync()) {
    stderr.writeln('Package executable does not exist: $executable');
    exitCode = 2;
    return;
  }

  final workspace = await _createWorkspace();
  final dataDirectory = Directory('${workspace.path}/data');
  final downloadDirectory = Directory('${workspace.path}/downloads');
  await dataDirectory.create(recursive: true);
  await downloadDirectory.create(recursive: true);
  final fixture = await _FixtureServer.start();
  final enginePort = await _reserveLoopbackPort();
  final address = '127.0.0.1:$enginePort';
  final logs = StringBuffer();
  Process? process;
  HttpClient? client;
  try {
    process = await Process.start(
      executableFile.absolute.path,
      const <String>[],
      environment: <String, String>{
        ...Platform.environment,
        'DOWNPEED_PACKAGE_SMOKE': '1',
        'DOWNPEED_SMOKE_ENGINE_ADDRESS': address,
        'DOWNPEED_SMOKE_DATA_DIR': dataDirectory.path,
        'DOWNPEED_SMOKE_DOWNLOAD_DIR': downloadDirectory.path,
      },
    );
    unawaited(
      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(logs.write),
    );
    unawaited(
      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(logs.write),
    );
    var processExited = false;
    process.exitCode.then((_) => processExited = true);

    client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    await _waitForHealth(client, address, () => processExited);
    final resolution = await _jsonRequest(
      client,
      'POST',
      Uri.parse('http://$address/api/v1/tasks/resolve'),
      <String, Object?>{'url': fixture.uri.toString()},
    );
    final resolutionData = _data(resolution);
    final created = await _jsonRequest(
      client,
      'POST',
      Uri.parse('http://$address/api/v1/tasks'),
      <String, Object?>{
        'url': resolutionData['url'],
        'fileName': resolutionData['fileName'],
        'saveDirectory': downloadDirectory.path,
        'expectedSize': resolutionData['size'],
        'acceptRanges': resolutionData['acceptRanges'],
        'etag': resolutionData['etag'],
        'lastModified': resolutionData['lastModified'],
      },
    );
    final taskID = _data(created)['id'];
    if (taskID is! String || taskID.isEmpty) {
      throw const FormatException('The packaged engine returned no task id.');
    }
    final completed = await _waitForCompletion(client, address, taskID);
    final filePath = completed['filePath'];
    if (filePath is! String || filePath.isEmpty) {
      throw const FormatException('The completed task returned no file path.');
    }
    final downloaded = await File(filePath).readAsBytes();
    if (!_sameBytes(downloaded, fixture.payload)) {
      throw const FormatException('The packaged download content is invalid.');
    }
    stdout.writeln(
      'Package smoke test passed: embedded engine and local download are healthy.',
    );
  } on Object catch (error) {
    stderr.writeln('Package smoke test failed: $error');
    final output = logs.toString().trim();
    if (output.isNotEmpty) {
      stderr.writeln(
        output.length > 4000 ? output.substring(output.length - 4000) : output,
      );
    }
    exitCode = 1;
  } finally {
    client?.close(force: true);
    await fixture.close();
    if (process != null) {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
      }
    }
    try {
      await workspace.delete(recursive: true);
    } on FileSystemException {
      // The operating system may still be releasing a native file handle.
    }
  }
}

String _argument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) {
    throw FormatException('Missing required argument $name.');
  }
  return arguments[index + 1];
}

Future<Directory> _createWorkspace() async {
  if (!Platform.isMacOS) {
    return Directory.systemTemp.createTemp('downpeed-package-smoke-');
  }
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    throw const FileSystemException('The macOS home directory is unavailable.');
  }
  final containerTemp = Directory(
    '$home/Library/Containers/com.xiaoxi.downpeed/Data/tmp',
  );
  await containerTemp.create(recursive: true);
  return containerTemp.createTemp('downpeed-package-smoke-');
}

Future<int> _reserveLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<void> _waitForHealth(
  HttpClient client,
  String address,
  bool Function() processExited,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    if (processExited()) {
      throw const ProcessException(
        'Downpeed',
        <String>[],
        'The packaged app exited during startup.',
      );
    }
    try {
      final result = await _jsonRequest(
        client,
        'GET',
        Uri.parse('http://$address/api/v1/health'),
        null,
      );
      if (_data(result)['status'] == 'ok') return;
    } on Object {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  throw TimeoutException('The packaged engine did not become healthy.');
}

Future<Map<String, Object?>> _waitForCompletion(
  HttpClient client,
  String address,
  String taskID,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final result = await _jsonRequest(
      client,
      'GET',
      Uri.parse('http://$address/api/v1/tasks/${Uri.encodeComponent(taskID)}'),
      null,
    );
    final task = _data(result);
    final state = task['state'];
    if (state == 'completed') return task;
    if (state == 'failed' || state == 'canceled') {
      throw StateError('The packaged download entered state $state.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('The packaged download did not complete.');
}

Future<Map<String, Object?>> _jsonRequest(
  HttpClient client,
  String method,
  Uri uri,
  Map<String, Object?>? body,
) async {
  final request = await client
      .openUrl(method, uri)
      .timeout(const Duration(seconds: 3));
  request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close().timeout(const Duration(seconds: 15));
  final encoded = await utf8.decoder.bind(response).join();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException('HTTP ${response.statusCode}: $encoded', uri: uri);
  }
  final decoded = jsonDecode(encoded);
  if (decoded is! Map) {
    throw const FormatException('The packaged engine returned invalid JSON.');
  }
  return Map<String, Object?>.from(decoded);
}

Map<String, Object?> _data(Map<String, Object?> envelope) {
  final data = envelope['data'];
  if (data is! Map) {
    throw const FormatException('The packaged engine returned no data object.');
  }
  return Map<String, Object?>.from(data);
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class _FixtureServer {
  _FixtureServer._(this.server, this.payload);

  static const etag = '"downpeed-package-smoke-v1"';

  final HttpServer server;
  final Uint8List payload;

  Uri get uri => Uri.parse(
    'http://${server.address.address}:${server.port}/package-smoke.bin',
  );

  static Future<_FixtureServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final payload = Uint8List(256 * 1024);
    for (var index = 0; index < payload.length; index++) {
      payload[index] = (index * 19 + 7) & 0xff;
    }
    final fixture = _FixtureServer._(server, payload);
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
      ..set('content-disposition', 'attachment; filename="package-smoke.bin"');
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
    response.contentLength = payload.length;
    response.add(payload);
    await response.close();
  }
}
