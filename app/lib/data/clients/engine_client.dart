import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../domains/batch_task_result.dart';
import '../../domains/bt_resolution.dart';
import '../../domains/bt_diagnostics.dart';
import '../../domains/delete_task_result.dart';
import '../../domains/download_resolution.dart';
import '../../domains/download_task.dart';
import '../../domains/engine_diagnostics.dart';
import '../../domains/engine_info.dart';
import '../../domains/engine_settings.dart';

const defaultEngineBaseUrl = String.fromEnvironment(
  'DOWNPEED_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:17680',
);

abstract interface class EngineClient {
  Future<EngineInfo> fetchInfo();

  Future<EngineDiagnostics> fetchDiagnostics();

  Future<DiagnosticArchive> exportDiagnostics();

  Future<EngineSettings> fetchSettings();

  Future<EngineSettings> updateSettings({
    required String defaultDownloadDirectory,
    required FileConflictPolicy fileConflictPolicy,
    required SchedulerSettings scheduler,
    required BTPolicySettings bitTorrent,
  });

  Future<DownloadResolution> resolveDownload(String url);

  Future<BTResolution> resolveMagnet(String magnet);

  Future<BTResolution> resolveTorrent(List<int> bytes);

  Future<BTDiagnostics> fetchBTDiagnostics(String taskId);

  Future<DownloadTask> createTask({
    required String url,
    required String fileName,
    required String saveDirectory,
    int expectedSize = -1,
    bool acceptRanges = false,
    String etag = '',
    String lastModified = '',
    DateTime? scheduledAt,
  });

  Future<DownloadTask> createBTTask({
    required List<int> metadata,
    required String saveDirectory,
    required List<int> selectedFileIndexes,
    required List<String> explicitPeers,
  });

  Future<BatchTaskResult> createTasks(List<CreateTaskInput> tasks);

  Future<List<DownloadTask>> fetchTasks();

  Future<DownloadTask> fetchTask(String id);

  Future<DownloadTask> pauseTask(String id);

  Future<DownloadTask> resumeTask(String id);

  Future<DownloadTask> retryTask(String id);

  Future<DownloadTask> cancelTask(String id);

  Future<DeleteTaskResult> deleteTask(String id, {bool deleteFile = false});

  Future<BatchDeleteTaskResult> deleteTasks(
    List<String> ids, {
    bool deleteFiles = false,
  });

  Future<BatchDeleteTaskResult> clearCompletedTasks();

  Future<BatchTaskResult> actOnTasks(List<String> ids, BatchTaskAction action);

  Stream<DownloadTaskEvent> watchTaskEvents();
}

class EngineClientException implements Exception {
  const EngineClientException(
    this.message, {
    this.code = 'engine_request_failed',
    this.retryable = true,
  });

  final String message;
  final String code;
  final bool retryable;

  @override
  String toString() => message;
}

class DioEngineClient implements EngineClient {
  DioEngineClient({Dio? dio, String baseUrl = defaultEngineBaseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 2),
              receiveTimeout: const Duration(seconds: 3),
              responseType: ResponseType.json,
              headers: const {'Accept': 'application/json'},
            ),
          );

  final Dio _dio;

  static const maxDiagnosticArchiveBytes = 8 << 20;

  @override
  Future<EngineInfo> fetchInfo() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/info');
      return EngineInfo.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on FormatException {
      throw const EngineClientException(
        'The engine version is incompatible with this app.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
  }

  @override
  Future<EngineDiagnostics> fetchDiagnostics() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/diagnostics',
      );
      return EngineDiagnostics.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned unsupported diagnostic information.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
  }

  @override
  Future<DiagnosticArchive> exportDiagnostics() async {
    try {
      final response = await _dio.post<List<int>>(
        '/api/v1/diagnostics/export',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 15),
          headers: const {'Accept': 'application/zip'},
        ),
      );
      final bytes = response.data;
      if (bytes == null ||
          bytes.isEmpty ||
          bytes.length > maxDiagnosticArchiveBytes) {
        throw const FormatException('Invalid diagnostic archive.');
      }
      final filename = _diagnosticFilename(
        response.headers.value('x-downpeed-filename'),
      );
      return DiagnosticArchive(
        filename: filename,
        bytes: Uint8List.fromList(bytes),
      );
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned an invalid diagnostic archive.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
  }

  @override
  Future<EngineSettings> fetchSettings() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/settings');
      return EngineSettings.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on FormatException {
      throw const EngineClientException(
        'The engine returned unsupported settings.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
  }

  @override
  Future<EngineSettings> updateSettings({
    required String defaultDownloadDirectory,
    required FileConflictPolicy fileConflictPolicy,
    required SchedulerSettings scheduler,
    required BTPolicySettings bitTorrent,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/v1/settings',
        data: <String, dynamic>{
          'defaultDownloadDirectory': defaultDownloadDirectory,
          'fileConflictPolicy': fileConflictPolicy.apiValue,
          'scheduler': scheduler.toJson(),
          'bitTorrent': bitTorrent.toJson(),
        },
      );
      return EngineSettings.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on FormatException {
      throw const EngineClientException(
        'The engine returned unsupported settings.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
  }

  @override
  Future<DownloadResolution> resolveDownload(String url) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/tasks/resolve',
        data: <String, dynamic>{'url': url},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      return DownloadResolution.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on FormatException {
      throw const EngineClientException(
        'The engine returned unsupported download metadata.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
  }

  @override
  Future<BTResolution> resolveMagnet(String magnet) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/bt/resolve/magnet',
        data: <String, dynamic>{'magnet': magnet},
      );
      return BTResolution.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned unsupported BT metadata.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
  }

  @override
  Future<BTResolution> resolveTorrent(List<int> bytes) async {
    try {
      final payload = Uint8List.fromList(bytes);
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/bt/resolve/torrent',
        data: Stream<List<int>>.value(payload),
        options: Options(
          contentType: 'application/x-bittorrent',
          headers: <String, dynamic>{'Content-Length': payload.length},
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return BTResolution.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned unsupported BT metadata.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
  }

  @override
  Future<BTDiagnostics> fetchBTDiagnostics(String taskId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/tasks/${Uri.encodeComponent(taskId)}/bt/diagnostics',
      );
      return BTDiagnostics.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned unsupported BT diagnostics.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
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
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/tasks',
        data: <String, dynamic>{
          'url': url,
          'fileName': fileName,
          'saveDirectory': saveDirectory,
          'expectedSize': expectedSize,
          'acceptRanges': acceptRanges,
          if (etag.isNotEmpty) 'etag': etag,
          if (lastModified.isNotEmpty) 'lastModified': lastModified,
          if (scheduledAt != null)
            'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        },
      );
      return DownloadTask.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on FormatException {
      throw const EngineClientException(
        'The engine returned an unsupported download task.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
  }

  @override
  Future<DownloadTask> createBTTask({
    required List<int> metadata,
    required String saveDirectory,
    required List<int> selectedFileIndexes,
    required List<String> explicitPeers,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/bt/tasks',
        data: <String, dynamic>{
          'metadata': base64Encode(metadata),
          'saveDirectory': saveDirectory,
          'selectedFileIndexes': selectedFileIndexes,
          'explicitPeers': explicitPeers,
        },
      );
      return DownloadTask.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on FormatException {
      throw const EngineClientException(
        'The engine returned an unsupported BT download task.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
  }

  @override
  Future<BatchTaskResult> createTasks(List<CreateTaskInput> tasks) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/tasks/batch',
        data: <String, dynamic>{
          'tasks': tasks.map((task) => task.toJson()).toList(growable: false),
        },
      );
      return BatchTaskResult.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned an unsupported batch task result.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<DownloadTask>> fetchTasks() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/tasks');
      final data = _readRawData(response.data);
      if (data is! List) {
        throw const FormatException('Invalid download task list.');
      }
      return data
          .map(
            (value) =>
                DownloadTask.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false);
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned an unsupported task list.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
  }

  @override
  Future<DownloadTask> fetchTask(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/tasks/${Uri.encodeComponent(id)}',
      );
      return DownloadTask.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on FormatException {
      throw const EngineClientException(
        'The engine returned an unsupported download task.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
  }

  @override
  Future<DownloadTask> cancelTask(String id) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/v1/tasks/${Uri.encodeComponent(id)}/cancel',
      );
      return DownloadTask.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on FormatException {
      throw const EngineClientException(
        'The engine returned an unsupported download task.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
  }

  @override
  Future<DeleteTaskResult> deleteTask(
    String id, {
    bool deleteFile = false,
  }) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/api/v1/tasks/${Uri.encodeComponent(id)}/record',
        queryParameters: <String, dynamic>{'deleteFiles': deleteFile},
      );
      return DeleteTaskResult.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned an unsupported deleted task result.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
  }

  @override
  Future<BatchDeleteTaskResult> deleteTasks(
    List<String> ids, {
    bool deleteFiles = false,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/tasks/batch/delete',
        data: <String, dynamic>{'ids': ids, 'deleteFiles': deleteFiles},
      );
      return BatchDeleteTaskResult.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned an unsupported batch deleted task result.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
  }

  @override
  Future<BatchDeleteTaskResult> clearCompletedTasks() async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/api/v1/tasks/completed',
      );
      return BatchDeleteTaskResult.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned an unsupported batch deleted task result.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
  }

  @override
  Future<BatchTaskResult> actOnTasks(
    List<String> ids,
    BatchTaskAction action,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/tasks/batch/actions',
        data: <String, dynamic>{'ids': ids, 'action': action.apiValue},
      );
      return BatchTaskResult.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        throw const EngineClientException(
          'The engine returned an unsupported batch task result.',
          code: 'incompatible_engine',
          retryable: false,
        );
      }
      rethrow;
    }
  }

  @override
  Future<DownloadTask> pauseTask(String id) => _updateTask(id, 'pause');

  @override
  Future<DownloadTask> resumeTask(String id) => _updateTask(id, 'resume');

  @override
  Future<DownloadTask> retryTask(String id) =>
      _updateTask(id, 'retry', method: 'POST');

  Future<DownloadTask> _updateTask(
    String id,
    String action, {
    String method = 'PUT',
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        '/api/v1/tasks/${Uri.encodeComponent(id)}/$action',
        options: Options(method: method),
      );
      return DownloadTask.fromJson(_readData(response.data));
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on FormatException {
      throw const EngineClientException(
        'The engine returned an unsupported download task.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
  }

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() async* {
    try {
      final response = await _dio.get<ResponseBody>(
        '/api/v1/events',
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          headers: const {'Accept': 'text/event-stream'},
        ),
      );
      final body = response.data;
      if (body == null) {
        throw const FormatException('Missing task event stream.');
      }
      final lines = body.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final value = jsonDecode(line.substring(5).trim());
        if (value is! Map) {
          throw const FormatException('Invalid task event payload.');
        }
        yield DownloadTaskEvent.fromJson(Map<String, dynamic>.from(value));
      }
    } on EngineClientException {
      rethrow;
    } on DioException catch (error) {
      throw _normalizeDioError(error);
    } on FormatException {
      throw const EngineClientException(
        'The engine task event stream is incompatible with this app.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
  }

  Map<String, dynamic> _readData(Map<String, dynamic>? body) {
    final data = _readRawData(body);
    if (data is! Map) {
      throw const EngineClientException(
        'The engine returned an unsupported response.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
    return Map<String, dynamic>.from(data);
  }

  dynamic _readRawData(Map<String, dynamic>? body) {
    final error = body?['error'];
    if (error is Map) {
      throw EngineClientException(
        error['message']?.toString() ?? 'Engine request failed.',
        code: error['code']?.toString() ?? 'engine_request_failed',
        retryable: error['retryable'] == true,
      );
    }
    if (body == null || !body.containsKey('data')) {
      throw const EngineClientException(
        'The engine returned an unsupported response.',
        code: 'incompatible_engine',
        retryable: false,
      );
    }
    return body['data'];
  }

  EngineClientException _normalizeDioError(DioException error) {
    final responseBody = _decodedResponseBody(error.response?.data);
    if (responseBody is Map) {
      final responseError = responseBody['error'];
      if (responseError is Map) {
        return EngineClientException(
          responseError['message']?.toString() ?? 'Engine request failed.',
          code: responseError['code']?.toString() ?? 'engine_request_failed',
          retryable: responseError['retryable'] == true,
        );
      }
    }
    final retryable = switch (error.type) {
      DioExceptionType.badResponse =>
        (error.response?.statusCode ?? 500) >= 500,
      DioExceptionType.cancel => false,
      _ => true,
    };
    return EngineClientException(
      retryable
          ? 'The local Downpeed engine is not reachable.'
          : 'The engine rejected the request.',
      code: retryable ? 'engine_unreachable' : 'engine_rejected',
      retryable: retryable,
    );
  }

  dynamic _decodedResponseBody(dynamic body) {
    if (body is List<int>) {
      try {
        return jsonDecode(utf8.decode(body));
      } on Object {
        return body;
      }
    }
    return body;
  }

  String _diagnosticFilename(String? value) {
    final filename = value?.trim() ?? '';
    if (RegExp(
      r'^downpeed-diagnostics-[0-9]{8}-[0-9]{6}Z\.zip$',
    ).hasMatch(filename)) {
      return filename;
    }
    return 'downpeed-diagnostics.zip';
  }
}
