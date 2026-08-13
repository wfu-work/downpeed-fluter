enum DownloadTaskState {
  queued,
  downloading,
  retrying,
  paused,
  completed,
  failed,
  canceled,
}

enum DownloadProtocol { http, bt }

class DownloadTaskError {
  const DownloadTaskError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  factory DownloadTaskError.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final message = json['message'];
    final retryable = json['retryable'];
    if (code is! String || message is! String || retryable is! bool) {
      throw const FormatException('Invalid download task error.');
    }
    return DownloadTaskError(
      code: code,
      message: message,
      retryable: retryable,
    );
  }

  final String code;
  final String message;
  final bool retryable;
}

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.url,
    required this.finalUrl,
    required this.fileName,
    required this.saveDirectory,
    required this.filePath,
    required this.state,
    required this.downloaded,
    required this.total,
    required this.speedBps,
    required this.createdAt,
    required this.updatedAt,
    this.protocol = DownloadProtocol.http,
    this.connections = 0,
    this.retryCount = 0,
    this.nextRetryAt,
    this.error,
    this.completedAt,
  });

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Missing download task field: $key');
      }
      return value;
    }

    int requiredInt(String key) {
      final value = json[key];
      if (value is! int) {
        throw FormatException('Missing download task field: $key');
      }
      return value;
    }

    DateTime requiredDate(String key) {
      final value = DateTime.tryParse(requiredString(key));
      if (value == null) {
        throw FormatException('Invalid download task date: $key');
      }
      return value;
    }

    final state = switch (requiredString('state')) {
      'queued' => DownloadTaskState.queued,
      'downloading' => DownloadTaskState.downloading,
      'retrying' => DownloadTaskState.retrying,
      'paused' => DownloadTaskState.paused,
      'completed' => DownloadTaskState.completed,
      'failed' => DownloadTaskState.failed,
      'canceled' => DownloadTaskState.canceled,
      _ => throw const FormatException('Unknown download task state.'),
    };
    final errorValue = json['error'];
    final completedValue = json['completedAt'];
    final downloaded = requiredInt('downloaded');
    final total = requiredInt('total');
    final speed = requiredInt('speedBps');
    final retryCountValue = json['retryCount'] ?? 0;
    final nextRetryValue = json['nextRetryAt'];
    final protocol = switch (json['protocol'] ?? 'http') {
      'http' => DownloadProtocol.http,
      'bt' => DownloadProtocol.bt,
      _ => throw const FormatException('Unknown download task protocol.'),
    };
    final connectionsValue = json['connections'] ?? 0;
    if (downloaded < 0 ||
        total < -1 ||
        speed < 0 ||
        connectionsValue is! int ||
        connectionsValue < 0 ||
        retryCountValue is! int ||
        retryCountValue < 0 ||
        (nextRetryValue != null &&
            (nextRetryValue is! String ||
                DateTime.tryParse(nextRetryValue) == null))) {
      throw const FormatException('Invalid download task progress.');
    }

    return DownloadTask(
      id: requiredString('id'),
      url: requiredString('url'),
      finalUrl: requiredString('finalUrl'),
      fileName: requiredString('fileName'),
      saveDirectory: requiredString('saveDirectory'),
      filePath: requiredString('filePath'),
      state: state,
      downloaded: downloaded,
      total: total,
      speedBps: speed,
      protocol: protocol,
      connections: connectionsValue,
      retryCount: retryCountValue,
      nextRetryAt: nextRetryValue is String
          ? DateTime.parse(nextRetryValue)
          : null,
      error: errorValue is Map
          ? DownloadTaskError.fromJson(Map<String, dynamic>.from(errorValue))
          : null,
      createdAt: requiredDate('createdAt'),
      updatedAt: requiredDate('updatedAt'),
      completedAt: completedValue is String
          ? DateTime.tryParse(completedValue)
          : null,
    );
  }

  final String id;
  final String url;
  final String finalUrl;
  final String fileName;
  final String saveDirectory;
  final String filePath;
  final DownloadTaskState state;
  final int downloaded;
  final int total;
  final int speedBps;
  final DownloadProtocol protocol;
  final int connections;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DownloadTaskError? error;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  double get progress =>
      total > 0 ? (downloaded / total).clamp(0, 1).toDouble() : 0;
  bool get isTerminal => switch (state) {
    DownloadTaskState.completed ||
    DownloadTaskState.failed ||
    DownloadTaskState.canceled => true,
    DownloadTaskState.queued ||
    DownloadTaskState.downloading ||
    DownloadTaskState.retrying ||
    DownloadTaskState.paused => false,
  };

  bool get canPause =>
      state == DownloadTaskState.queued ||
      state == DownloadTaskState.downloading ||
      state == DownloadTaskState.retrying;
  bool get canResume => state == DownloadTaskState.paused;
  bool get canRetry =>
      state == DownloadTaskState.failed && (error?.retryable ?? false);
  bool get canCancel => !isTerminal;
}

class DownloadTaskEvent {
  const DownloadTaskEvent({required this.type, required this.task});

  factory DownloadTaskEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final task = json['task'];
    if (type is! String || task is! Map) {
      throw const FormatException('Invalid download task event.');
    }
    return DownloadTaskEvent(
      type: type,
      task: DownloadTask.fromJson(Map<String, dynamic>.from(task)),
    );
  }

  final String type;
  final DownloadTask task;
}
