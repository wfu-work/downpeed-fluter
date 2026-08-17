import 'dart:typed_data';

class EngineDiagnostics {
  const EngineDiagnostics({
    required this.generatedAt,
    required this.storage,
    required this.tasks,
    required this.privacy,
  });

  factory EngineDiagnostics.fromJson(Map<String, dynamic> json) {
    final generatedAt = DateTime.tryParse(
      json['generatedAt']?.toString() ?? '',
    );
    final storage = json['storage'];
    final tasks = json['tasks'];
    final privacy = json['privacy'];
    if (generatedAt == null ||
        storage is! Map ||
        tasks is! Map ||
        privacy is! Map) {
      throw const FormatException('Invalid engine diagnostics.');
    }
    return EngineDiagnostics(
      generatedAt: generatedAt,
      storage: DiagnosticStorage.fromJson(Map<String, dynamic>.from(storage)),
      tasks: DiagnosticTaskSummary.fromJson(Map<String, dynamic>.from(tasks)),
      privacy: DiagnosticPrivacy.fromJson(Map<String, dynamic>.from(privacy)),
    );
  }

  final DateTime generatedAt;
  final DiagnosticStorage storage;
  final DiagnosticTaskSummary tasks;
  final DiagnosticPrivacy privacy;
}

class DiagnosticStorage {
  const DiagnosticStorage({
    required this.dataDirectory,
    required this.databasePath,
    required this.databaseSizeBytes,
    required this.databaseAvailable,
    required this.logsAvailable,
    required this.logPath,
  });

  factory DiagnosticStorage.fromJson(Map<String, dynamic> json) {
    String readString(String key, {bool allowEmpty = false}) {
      final value = json[key];
      if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
        throw FormatException('Invalid diagnostic storage field: $key');
      }
      return value;
    }

    bool readBool(String key) {
      final value = json[key];
      if (value is! bool) {
        throw FormatException('Invalid diagnostic storage field: $key');
      }
      return value;
    }

    final databaseSizeBytes = json['databaseSizeBytes'];
    if (databaseSizeBytes is! int || databaseSizeBytes < 0) {
      throw const FormatException('Invalid diagnostic database size.');
    }
    final logsAvailable = readBool('logsAvailable');
    final logPath = json['logPath'] == null
        ? ''
        : readString('logPath', allowEmpty: true);
    if (logsAvailable && logPath.trim().isEmpty) {
      throw const FormatException('Missing diagnostic log path.');
    }
    return DiagnosticStorage(
      dataDirectory: readString('dataDirectory'),
      databasePath: readString('databasePath'),
      databaseSizeBytes: databaseSizeBytes,
      databaseAvailable: readBool('databaseAvailable'),
      logsAvailable: logsAvailable,
      logPath: logPath,
    );
  }

  final String dataDirectory;
  final String databasePath;
  final int databaseSizeBytes;
  final bool databaseAvailable;
  final bool logsAvailable;
  final String logPath;
}

class DiagnosticTaskSummary {
  const DiagnosticTaskSummary({
    required this.total,
    required this.active,
    required this.queued,
    required this.paused,
    required this.completed,
    required this.failed,
    required this.canceled,
    required this.http,
    required this.bitTorrent,
  });

  factory DiagnosticTaskSummary.fromJson(Map<String, dynamic> json) {
    int readCount(String key) {
      final value = json[key];
      if (value is! int || value < 0) {
        throw FormatException('Invalid diagnostic task count: $key');
      }
      return value;
    }

    return DiagnosticTaskSummary(
      total: readCount('total'),
      active: readCount('active'),
      queued: readCount('queued'),
      paused: readCount('paused'),
      completed: readCount('completed'),
      failed: readCount('failed'),
      canceled: readCount('canceled'),
      http: readCount('http'),
      bitTorrent: readCount('bitTorrent'),
    );
  }

  final int total;
  final int active;
  final int queued;
  final int paused;
  final int completed;
  final int failed;
  final int canceled;
  final int http;
  final int bitTorrent;
}

class DiagnosticPrivacy {
  const DiagnosticPrivacy({
    required this.pathsRedacted,
    required this.taskDetailsIncluded,
    required this.logsIncluded,
  });

  factory DiagnosticPrivacy.fromJson(Map<String, dynamic> json) {
    bool readBool(String key) {
      final value = json[key];
      if (value is! bool) {
        throw FormatException('Invalid diagnostic privacy field: $key');
      }
      return value;
    }

    return DiagnosticPrivacy(
      pathsRedacted: readBool('pathsRedacted'),
      taskDetailsIncluded: readBool('taskDetailsIncluded'),
      logsIncluded: readBool('logsIncluded'),
    );
  }

  final bool pathsRedacted;
  final bool taskDetailsIncluded;
  final bool logsIncluded;
}

class DiagnosticArchive {
  const DiagnosticArchive({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;
}
