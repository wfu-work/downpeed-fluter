class EngineSettings {
  const EngineSettings({
    required this.defaultDownloadDirectory,
    required this.fileConflictPolicy,
    required this.scheduler,
    required this.bitTorrent,
  });

  factory EngineSettings.fromJson(Map<String, dynamic> json) {
    final directory = json['defaultDownloadDirectory'];
    if (directory is! String || directory.trim().isEmpty) {
      throw const FormatException('Invalid default download directory.');
    }
    final scheduler = json['scheduler'];
    if (scheduler is! Map) {
      throw const FormatException('Invalid scheduler settings.');
    }
    final bitTorrent = json['bitTorrent'];
    if (bitTorrent is! Map) {
      throw const FormatException('Invalid BitTorrent policy.');
    }
    return EngineSettings(
      defaultDownloadDirectory: directory,
      fileConflictPolicy: FileConflictPolicy.fromJson(
        json['fileConflictPolicy'],
      ),
      scheduler: SchedulerSettings.fromJson(
        Map<String, dynamic>.from(scheduler),
      ),
      bitTorrent: BTPolicySettings.fromJson(
        Map<String, dynamic>.from(bitTorrent),
      ),
    );
  }

  final String defaultDownloadDirectory;
  final FileConflictPolicy fileConflictPolicy;
  final SchedulerSettings scheduler;
  final BTPolicySettings bitTorrent;
}

enum FileConflictPolicy {
  fail('fail'),
  uniquify('uniquify');

  const FileConflictPolicy(this.apiValue);

  static FileConflictPolicy fromJson(Object? value) => switch (value) {
    'fail' => FileConflictPolicy.fail,
    'uniquify' => FileConflictPolicy.uniquify,
    _ => throw const FormatException('Invalid file conflict policy.'),
  };

  final String apiValue;
}

class SchedulerSettings {
  const SchedulerSettings({
    required this.maxConcurrentTasks,
    required this.downloadRateLimit,
    required this.maxRetries,
  });

  static const minimumConcurrentTasks = 1;
  static const maximumConcurrentTasks = 64;
  static const minimumRetries = 0;
  static const maximumRetries = 10;

  factory SchedulerSettings.fromJson(Map<String, dynamic> json) {
    final maxConcurrentTasks = json['maxConcurrentTasks'];
    final downloadRateLimit = json['downloadRateLimit'];
    final maxRetries = json['maxRetries'];
    if (maxConcurrentTasks is! int ||
        maxConcurrentTasks < minimumConcurrentTasks ||
        maxConcurrentTasks > maximumConcurrentTasks) {
      throw const FormatException('Invalid maximum concurrent tasks.');
    }
    if (downloadRateLimit is! int || downloadRateLimit < 0) {
      throw const FormatException('Invalid download rate limit.');
    }
    if (maxRetries is! int ||
        maxRetries < minimumRetries ||
        maxRetries > maximumRetries) {
      throw const FormatException('Invalid automatic retry count.');
    }
    return SchedulerSettings(
      maxConcurrentTasks: maxConcurrentTasks,
      downloadRateLimit: downloadRateLimit,
      maxRetries: maxRetries,
    );
  }

  final int maxConcurrentTasks;
  final int downloadRateLimit;
  final int maxRetries;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'maxConcurrentTasks': maxConcurrentTasks,
    'downloadRateLimit': downloadRateLimit,
    'maxRetries': maxRetries,
  };

  SchedulerSettings copyWith({
    int? maxConcurrentTasks,
    int? downloadRateLimit,
    int? maxRetries,
  }) => SchedulerSettings(
    maxConcurrentTasks: maxConcurrentTasks ?? this.maxConcurrentTasks,
    downloadRateLimit: downloadRateLimit ?? this.downloadRateLimit,
    maxRetries: maxRetries ?? this.maxRetries,
  );
}

class BTPolicySettings {
  const BTPolicySettings({
    required this.maxPeerConnections,
    required this.explicitPeersOnly,
    required this.trackersEnabled,
    required this.dhtEnabled,
    required this.pexEnabled,
    required this.webSeedsEnabled,
    required this.inboundEnabled,
    required this.ipv6Enabled,
    required this.uploadEnabled,
    required this.seedingEnabled,
  });

  factory BTPolicySettings.fromJson(Map<String, dynamic> json) {
    int readPeerBudget() {
      final value = json['maxPeerConnections'];
      if (value is! int || value < 1 || value > 80) {
        throw const FormatException('Invalid BitTorrent peer budget.');
      }
      return value;
    }

    bool readBool(String key) {
      final value = json[key];
      if (value is! bool) {
        throw FormatException('Invalid BitTorrent policy field: $key');
      }
      return value;
    }

    return BTPolicySettings(
      maxPeerConnections: readPeerBudget(),
      explicitPeersOnly: readBool('explicitPeersOnly'),
      trackersEnabled: readBool('trackersEnabled'),
      dhtEnabled: readBool('dhtEnabled'),
      pexEnabled: readBool('pexEnabled'),
      webSeedsEnabled: readBool('webSeedsEnabled'),
      inboundEnabled: readBool('inboundEnabled'),
      ipv6Enabled: readBool('ipv6Enabled'),
      uploadEnabled: readBool('uploadEnabled'),
      seedingEnabled: readBool('seedingEnabled'),
    );
  }

  final int maxPeerConnections;
  final bool explicitPeersOnly;
  final bool trackersEnabled;
  final bool dhtEnabled;
  final bool pexEnabled;
  final bool webSeedsEnabled;
  final bool inboundEnabled;
  final bool ipv6Enabled;
  final bool uploadEnabled;
  final bool seedingEnabled;

  bool get restrictedCapabilitiesDisabled =>
      explicitPeersOnly &&
      !trackersEnabled &&
      !dhtEnabled &&
      !pexEnabled &&
      !webSeedsEnabled &&
      !inboundEnabled &&
      !ipv6Enabled &&
      !uploadEnabled &&
      !seedingEnabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'maxPeerConnections': maxPeerConnections,
    'explicitPeersOnly': explicitPeersOnly,
    'trackersEnabled': trackersEnabled,
    'dhtEnabled': dhtEnabled,
    'pexEnabled': pexEnabled,
    'webSeedsEnabled': webSeedsEnabled,
    'inboundEnabled': inboundEnabled,
    'ipv6Enabled': ipv6Enabled,
    'uploadEnabled': uploadEnabled,
    'seedingEnabled': seedingEnabled,
  };

  BTPolicySettings copyWith({int? maxPeerConnections}) => BTPolicySettings(
    maxPeerConnections: maxPeerConnections ?? this.maxPeerConnections,
    explicitPeersOnly: explicitPeersOnly,
    trackersEnabled: trackersEnabled,
    dhtEnabled: dhtEnabled,
    pexEnabled: pexEnabled,
    webSeedsEnabled: webSeedsEnabled,
    inboundEnabled: inboundEnabled,
    ipv6Enabled: ipv6Enabled,
    uploadEnabled: uploadEnabled,
    seedingEnabled: seedingEnabled,
  );
}
