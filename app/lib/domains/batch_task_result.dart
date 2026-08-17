import 'download_task.dart';

const maxTaskBatchSize = 100;

enum BatchTaskAction {
  pause('pause'),
  resume('resume'),
  cancel('cancel');

  const BatchTaskAction(this.apiValue);

  final String apiValue;
}

class CreateTaskInput {
  const CreateTaskInput({
    required this.url,
    required this.fileName,
    required this.saveDirectory,
    this.expectedSize = -1,
    this.acceptRanges = false,
    this.etag = '',
    this.lastModified = '',
    this.scheduledAt,
  });

  final String url;
  final String fileName;
  final String saveDirectory;
  final int expectedSize;
  final bool acceptRanges;
  final String etag;
  final String lastModified;
  final DateTime? scheduledAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url,
    'fileName': fileName,
    'saveDirectory': saveDirectory,
    'expectedSize': expectedSize,
    'acceptRanges': acceptRanges,
    if (etag.isNotEmpty) 'etag': etag,
    if (lastModified.isNotEmpty) 'lastModified': lastModified,
    if (scheduledAt != null)
      'scheduledAt': scheduledAt!.toUtc().toIso8601String(),
  };
}

class BatchTaskError {
  const BatchTaskError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  factory BatchTaskError.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final message = json['message'];
    final retryable = json['retryable'];
    if (code is! String || message is! String || retryable is! bool) {
      throw const FormatException('Invalid batch task error.');
    }
    return BatchTaskError(code: code, message: message, retryable: retryable);
  }

  final String code;
  final String message;
  final bool retryable;
}

class BatchTaskItemResult {
  const BatchTaskItemResult({
    required this.index,
    this.id,
    this.task,
    this.error,
  });

  factory BatchTaskItemResult.fromJson(Map<String, dynamic> json) {
    final index = json['index'];
    final id = json['id'];
    final task = json['task'];
    final error = json['error'];
    if (index is! int ||
        index < 0 ||
        (id != null && id is! String) ||
        (task != null && task is! Map) ||
        (error != null && error is! Map)) {
      throw const FormatException('Invalid batch task item.');
    }
    return BatchTaskItemResult(
      index: index,
      id: id as String?,
      task: task is Map
          ? DownloadTask.fromJson(Map<String, dynamic>.from(task))
          : null,
      error: error is Map
          ? BatchTaskError.fromJson(Map<String, dynamic>.from(error))
          : null,
    );
  }

  final int index;
  final String? id;
  final DownloadTask? task;
  final BatchTaskError? error;

  bool get succeeded => task != null && error == null;
}

class BatchTaskResult {
  const BatchTaskResult({
    required this.items,
    required this.succeeded,
    required this.failed,
  });

  factory BatchTaskResult.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final succeeded = json['succeeded'];
    final failed = json['failed'];
    if (items is! List ||
        succeeded is! int ||
        succeeded < 0 ||
        failed is! int ||
        failed < 0 ||
        succeeded + failed != items.length) {
      throw const FormatException('Invalid batch task result.');
    }
    return BatchTaskResult(
      items: items
          .map(
            (item) => BatchTaskItemResult.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      succeeded: succeeded,
      failed: failed,
    );
  }

  final List<BatchTaskItemResult> items;
  final int succeeded;
  final int failed;

  Iterable<DownloadTask> get successfulTasks sync* {
    for (final item in items) {
      if (item.task case final task?) yield task;
    }
  }
}
