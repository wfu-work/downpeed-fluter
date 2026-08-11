enum EngineConnectionState { checking, online, offline }

class EngineInfo {
  const EngineInfo({
    required this.name,
    required this.version,
    required this.commit,
    required this.apiVersion,
    required this.goVersion,
    required this.os,
    required this.arch,
  });

  factory EngineInfo.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Missing engine field: $key');
      }
      return value;
    }

    return EngineInfo(
      name: requiredString('name'),
      version: requiredString('version'),
      commit: requiredString('commit'),
      apiVersion: requiredString('apiVersion'),
      goVersion: requiredString('goVersion'),
      os: requiredString('os'),
      arch: requiredString('arch'),
    );
  }

  final String name;
  final String version;
  final String commit;
  final String apiVersion;
  final String goVersion;
  final String os;
  final String arch;
}
