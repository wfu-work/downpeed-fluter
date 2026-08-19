import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/batch_task_result.dart';
import 'package:downpeed_flutter/domains/bt_resolution.dart';
import 'package:downpeed_flutter/domains/bt_diagnostics.dart';
import 'package:downpeed_flutter/domains/delete_task_result.dart';
import 'package:downpeed_flutter/domains/download_resolution.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_diagnostics.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/domains/engine_settings.dart';

class StubEngineClient implements EngineClient {
  const StubEngineClient();

  @override
  Future<DownloadTask> cancelTask(String id) => throw UnimplementedError();

  @override
  Future<DeleteTaskResult> deleteTask(String id, {bool deleteFile = false}) =>
      throw UnimplementedError();

  @override
  Future<BatchDeleteTaskResult> deleteTasks(
    List<String> ids, {
    bool deleteFiles = false,
  }) => throw UnimplementedError();

  @override
  Future<BatchDeleteTaskResult> clearCompletedTasks() =>
      throw UnimplementedError();

  @override
  Future<BatchTaskResult> actOnTasks(
    List<String> ids,
    BatchTaskAction action,
  ) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<DownloadTask> createBTTask({
    required List<int> metadata,
    required String saveDirectory,
    required List<int> selectedFileIndexes,
    required List<String> explicitPeers,
  }) => throw UnimplementedError();

  @override
  Future<BatchTaskResult> createTasks(List<CreateTaskInput> tasks) =>
      throw UnimplementedError();

  @override
  Future<EngineInfo> fetchInfo() => throw UnimplementedError();

  @override
  Future<EngineDiagnostics> fetchDiagnostics() => throw UnimplementedError();

  @override
  Future<DiagnosticArchive> exportDiagnostics() => throw UnimplementedError();

  @override
  Future<BTDiagnostics> fetchBTDiagnostics(String taskId) =>
      throw UnimplementedError();

  @override
  Future<EngineSettings> fetchSettings() => throw UnimplementedError();

  @override
  Future<EngineSettings> updateSettings({
    required String defaultDownloadDirectory,
    required FileConflictPolicy fileConflictPolicy,
    required SchedulerSettings scheduler,
    required ProxySettings proxy,
    required BTPolicySettings bitTorrent,
  }) => throw UnimplementedError();

  @override
  Future<void> updateProxyCredential(String password) =>
      throw UnimplementedError();

  @override
  Future<ProxyTestResult> testProxy() => throw UnimplementedError();

  @override
  Future<DownloadTask> fetchTask(String id) => throw UnimplementedError();

  @override
  Future<List<DownloadTask>> fetchTasks() => throw UnimplementedError();

  @override
  Future<DownloadTask> pauseTask(String id) => throw UnimplementedError();

  @override
  Future<DownloadTask> resumeTask(String id) => throw UnimplementedError();

  @override
  Future<DownloadTask> retryTask(String id) => throw UnimplementedError();

  @override
  Future<DownloadResolution> resolveDownload(String url) =>
      throw UnimplementedError();

  @override
  Future<BTResolution> resolveMagnet(String magnet) =>
      throw UnimplementedError();

  @override
  Future<BTResolution> resolveTorrent(List<int> bytes) =>
      throw UnimplementedError();

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => const Stream.empty();
}
