class DownpeedBuildInfo {
  const DownpeedBuildInfo._();

  static const version = String.fromEnvironment(
    'DOWNPEED_APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const buildNumber = String.fromEnvironment(
    'DOWNPEED_BUILD_NUMBER',
    defaultValue: 'dev',
  );
  static const commit = String.fromEnvironment(
    'DOWNPEED_COMMIT',
    defaultValue: 'local',
  );
  static const buildDate = String.fromEnvironment(
    'DOWNPEED_BUILD_DATE',
    defaultValue: 'unknown',
  );
  static const releaseChannel = String.fromEnvironment(
    'DOWNPEED_RELEASE_CHANNEL',
    defaultValue: 'local',
  );

  static String get displayVersion =>
      buildNumber == 'dev' ? version : '$version ($buildNumber)';

  static String get shortCommit =>
      commit.length > 12 ? commit.substring(0, 12) : commit;

  static String get displayBuildDate => buildDate == 'unknown'
      ? buildDate
      : buildDate.replaceFirst('T', ' ').replaceFirst('Z', ' UTC');

  static String get displayBuild =>
      '$shortCommit · $releaseChannel · $displayBuildDate';
}
