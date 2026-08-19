import 'package:downpeed_flutter/configs/build_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('build information has stable local defaults', () {
    expect(DownpeedBuildInfo.version, isNotEmpty);
    expect(DownpeedBuildInfo.displayVersion, isNotEmpty);
    expect(DownpeedBuildInfo.shortCommit, isNotEmpty);
    expect(
      DownpeedBuildInfo.displayBuild,
      contains(DownpeedBuildInfo.releaseChannel),
    );
    expect(
      DownpeedBuildInfo.displayBuild,
      contains(DownpeedBuildInfo.displayBuildDate),
    );
  });
}
