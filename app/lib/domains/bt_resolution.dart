enum BTSourceType { magnet, torrent }

class BTFileEntry {
  const BTFileEntry({
    required this.index,
    required this.path,
    required this.size,
  });

  factory BTFileEntry.fromJson(Map<String, dynamic> json) {
    final index = json['index'];
    final path = json['path'];
    final size = json['size'];
    if (index is! int ||
        index < 0 ||
        path is! String ||
        path.isEmpty ||
        size is! int ||
        size < 0) {
      throw const FormatException('Invalid Torrent file metadata.');
    }
    return BTFileEntry(index: index, path: path, size: size);
  }

  final int index;
  final String path;
  final int size;

  String get fileName {
    final segments = path.split('/');
    return segments.isEmpty ? path : segments.last;
  }
}

class BTTracker {
  const BTTracker({required this.scheme, required this.host});

  factory BTTracker.fromJson(Map<String, dynamic> json) {
    final scheme = json['scheme'];
    final host = json['host'];
    if (scheme is! String ||
        scheme.isEmpty ||
        host is! String ||
        host.isEmpty) {
      throw const FormatException('Invalid Torrent tracker metadata.');
    }
    return BTTracker(scheme: scheme, host: host);
  }

  final String scheme;
  final String host;

  String get displayValue => '$scheme://$host';
}

class BTResolution {
  const BTResolution({
    required this.sourceType,
    required this.name,
    required this.infoHash,
    required this.v2InfoHash,
    required this.metadataAvailable,
    required this.isPrivate,
    required this.totalSize,
    required this.pieceLength,
    required this.files,
    required this.trackers,
  });

  factory BTResolution.fromJson(Map<String, dynamic> json) {
    final sourceType = switch (json['sourceType']) {
      'magnet' => BTSourceType.magnet,
      'torrent' => BTSourceType.torrent,
      _ => throw const FormatException('Invalid BT source type.'),
    };
    final name = json['name'];
    final infoHash = json['infoHash'] ?? '';
    final v2InfoHash = json['v2InfoHash'] ?? '';
    final metadataAvailable = json['metadataAvailable'];
    final isPrivate = json['private'];
    final totalSize = json['totalSize'];
    final pieceLength = json['pieceLength'];
    final files = json['files'];
    final trackers = json['trackers'];
    if (name is! String ||
        name.isEmpty ||
        infoHash is! String ||
        v2InfoHash is! String ||
        metadataAvailable is! bool ||
        isPrivate is! bool ||
        totalSize is! int ||
        totalSize < -1 ||
        pieceLength is! int ||
        pieceLength < 0 ||
        files is! List ||
        trackers is! List) {
      throw const FormatException('Invalid BT metadata.');
    }
    return BTResolution(
      sourceType: sourceType,
      name: name,
      infoHash: infoHash,
      v2InfoHash: v2InfoHash,
      metadataAvailable: metadataAvailable,
      isPrivate: isPrivate,
      totalSize: totalSize,
      pieceLength: pieceLength,
      files: files
          .map(
            (value) =>
                BTFileEntry.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false),
      trackers: trackers
          .map(
            (value) =>
                BTTracker.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false),
    );
  }

  final BTSourceType sourceType;
  final String name;
  final String infoHash;
  final String v2InfoHash;
  final bool metadataAvailable;
  final bool isPrivate;
  final int totalSize;
  final int pieceLength;
  final List<BTFileEntry> files;
  final List<BTTracker> trackers;

  String get displayHash => infoHash.isNotEmpty ? infoHash : v2InfoHash;
}
