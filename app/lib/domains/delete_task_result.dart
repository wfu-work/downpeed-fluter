import 'batch_task_result.dart';

class DeleteTaskResult {
  const DeleteTaskResult({required this.id, required this.fileDeleted});

  factory DeleteTaskResult.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final fileDeleted = json['fileDeleted'];
    if (id is! String || id.isEmpty || fileDeleted is! bool) {
      throw const FormatException('Invalid deleted task result.');
    }
    return DeleteTaskResult(id: id, fileDeleted: fileDeleted);
  }

  final String id;
  final bool fileDeleted;
}

class BatchDeleteTaskItemResult {
  const BatchDeleteTaskItemResult({
    required this.index,
    required this.id,
    required this.fileDeleted,
    this.error,
  });

  factory BatchDeleteTaskItemResult.fromJson(Map<String, dynamic> json) {
    final index = json['index'];
    final id = json['id'];
    final fileDeleted = json['fileDeleted'] ?? false;
    final error = json['error'];
    if (index is! int ||
        index < 0 ||
        id is! String ||
        id.isEmpty ||
        fileDeleted is! bool ||
        (error != null && error is! Map)) {
      throw const FormatException('Invalid batch deleted task item.');
    }
    return BatchDeleteTaskItemResult(
      index: index,
      id: id,
      fileDeleted: fileDeleted,
      error: error is Map
          ? BatchTaskError.fromJson(Map<String, dynamic>.from(error))
          : null,
    );
  }

  final int index;
  final String id;
  final bool fileDeleted;
  final BatchTaskError? error;

  bool get succeeded => error == null;
}

class BatchDeleteTaskResult {
  const BatchDeleteTaskResult({
    required this.items,
    required this.succeeded,
    required this.failed,
  });

  factory BatchDeleteTaskResult.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final succeeded = json['succeeded'];
    final failed = json['failed'];
    if (items is! List ||
        succeeded is! int ||
        succeeded < 0 ||
        failed is! int ||
        failed < 0 ||
        succeeded + failed != items.length) {
      throw const FormatException('Invalid batch deleted task result.');
    }
    return BatchDeleteTaskResult(
      items: items
          .map(
            (item) => BatchDeleteTaskItemResult.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      succeeded: succeeded,
      failed: failed,
    );
  }

  final List<BatchDeleteTaskItemResult> items;
  final int succeeded;
  final int failed;

  Iterable<String> get successfulIDs sync* {
    for (final item in items) {
      if (item.succeeded) yield item.id;
    }
  }
}
