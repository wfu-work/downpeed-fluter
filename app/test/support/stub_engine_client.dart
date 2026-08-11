import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/batch_task_result.dart';
import 'package:downpeed_flutter/domains/download_resolution.dart';
import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';

class StubEngineClient implements EngineClient {
  const StubEngineClient();

  @override
  Future<DownloadTask> cancelTask(String id) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<BatchTaskResult> createTasks(List<CreateTaskInput> tasks) =>
      throw UnimplementedError();

  @override
  Future<EngineInfo> fetchInfo() => throw UnimplementedError();

  @override
  Future<DownloadTask> fetchTask(String id) => throw UnimplementedError();

  @override
  Future<List<DownloadTask>> fetchTasks() => throw UnimplementedError();

  @override
  Future<DownloadTask> pauseTask(String id) => throw UnimplementedError();

  @override
  Future<DownloadTask> resumeTask(String id) => throw UnimplementedError();

  @override
  Future<DownloadResolution> resolveDownload(String url) =>
      throw UnimplementedError();

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => const Stream.empty();
}
