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

  static String get displayVersion =>
      buildNumber == 'dev' ? version : '$version ($buildNumber)';
}
