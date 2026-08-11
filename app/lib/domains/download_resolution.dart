class DownloadResolution {
  const DownloadResolution({
    required this.url,
    required this.finalUrl,
    required this.fileName,
    required this.size,
    required this.contentType,
    required this.acceptRanges,
    this.etag = '',
    this.lastModified = '',
  });

  factory DownloadResolution.fromJson(Map<String, dynamic> json) {
    String requiredString(String key, {bool allowEmpty = false}) {
      final value = json[key];
      if (value is! String || (!allowEmpty && value.isEmpty)) {
        throw FormatException('Missing resolution field: $key');
      }
      return value;
    }

    final size = json['size'];
    final acceptRanges = json['acceptRanges'];
    final etag = json['etag'] ?? '';
    final lastModified = json['lastModified'] ?? '';
    if (size is! int || size < -1 || acceptRanges is! bool) {
      throw const FormatException('Invalid download resolution metadata.');
    }
    if (etag is! String || lastModified is! String) {
      throw const FormatException('Invalid download resource validator.');
    }

    return DownloadResolution(
      url: requiredString('url'),
      finalUrl: requiredString('finalUrl'),
      fileName: requiredString('fileName'),
      size: size,
      contentType: requiredString('contentType', allowEmpty: true),
      acceptRanges: acceptRanges,
      etag: etag,
      lastModified: lastModified,
    );
  }

  final String url;
  final String finalUrl;
  final String fileName;
  final int size;
  final String contentType;
  final bool acceptRanges;
  final String etag;
  final String lastModified;

  String get finalHost => Uri.tryParse(finalUrl)?.host ?? '';
}
