import 'package:downpeed_flutter/app/routes/app_pages.dart';
import 'package:downpeed_flutter/services/app_command_service.dart';
import 'package:downpeed_flutter/services/app_link_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  group('DownpeedAppLinkParser', () {
    const parser = DownpeedAppLinkParser();

    test('accepts one encoded HTTP or HTTPS download target', () {
      const target = 'https://downloads.example.com/file.zip?source=browser';
      final link = parser.parse(_linkFor(target));

      expect(link.targetUrl, target);
    });

    test('rejects malformed commands and parameter ambiguity', () {
      final invalid = <String>[
        'DOWNPEED://download?url=https%3A%2F%2Fexample.com%2Fa.zip',
        'downpeed://downloads?url=https%3A%2F%2Fexample.com%2Fa.zip',
        'downpeed://download/path?url=https%3A%2F%2Fexample.com%2Fa.zip',
        'downpeed://download',
        'downpeed://download?url=https%3A%2F%2Fexample.com%2Fa.zip&url=https%3A%2F%2Fexample.com%2Fb.zip',
        'downpeed://download?url=https%3A%2F%2Fexample.com%2Fa.zip&source=x',
        'downpeed://download?url=https%3A%2F%2Fexample.com%2Fa.zip#fragment',
        'downpeed://user@download?url=https%3A%2F%2Fexample.com%2Fa.zip',
        'downpeed://download:80?url=https%3A%2F%2Fexample.com%2Fa.zip',
      ];

      for (final source in invalid) {
        expect(
          () => parser.parse(source),
          throwsA(isA<DownpeedAppLinkException>()),
        );
      }
    });

    test('rejects unsafe target URLs', () {
      final invalidTargets = <String>[
        'ftp://example.com/file.zip',
        'https:///file.zip',
        'https://user:password@example.com/file.zip',
        'https://example.com/file.zip\nsecond',
      ];

      for (final target in invalidTargets) {
        expect(
          () => parser.parse(_linkFor(target)),
          throwsA(isA<DownpeedAppLinkException>()),
        );
      }
    });

    test('enforces the full link byte limit without exposing its target', () {
      final secret = 'credential-do-not-repeat';
      final oversized = _linkFor(
        'https://example.com/${'a' * maxDownpeedAppLinkBytes}?token=$secret',
      );

      try {
        parser.parse(oversized);
        fail('Expected an oversized app link to be rejected.');
      } on DownpeedAppLinkException catch (error) {
        expect(error.code, DownpeedAppLinkError.tooLong);
        expect(error.toString(), isNot(contains(secret)));
      }
    });
  });

  test('queues cold-start commands until navigation is ready', () async {
    final events = <String>[];
    final service = AppCommandService(
      navigateTo: (route) async => events.add('route:$route'),
      openDownloadDialog: (initialUrl) async =>
          events.add('dialog:$initialUrl'),
      showWindow: () async => events.add('window'),
      focusTaskSearch: () async => events.add('focus'),
    );
    const target = 'https://example.com/cold-start.zip';

    final external = service.openExternalDownload(initialUrl: target);
    final focus = service.focusTaskSearch();
    expect(events, isEmpty);

    await service.markNavigationReady();
    await external;
    await focus;

    expect(events, <String>[
      'window',
      'route:${Routes.tasks}',
      'dialog:$target',
      'route:${Routes.tasks}',
      'focus',
    ]);
  });

  test('redacts command failures', () async {
    final service = AppCommandService(
      navigateTo: (_) async {},
      openDownloadDialog: (_) async {
        throw StateError('https://secret.example/private.zip');
      },
    );
    await service.markNavigationReady();

    await service.openNewDownload();

    expect(service.errorMessage.value, isNotNull);
    expect(service.errorMessage.value, isNot(contains('secret.example')));
  });

  test('forwards cold-start arguments and later native events', () async {
    final openedTargets = <String>[];
    final commands = AppCommandService(
      navigateTo: (_) async {},
      openDownloadDialog: (target) async => openedTargets.add(target),
      showWindow: () async {},
    );
    final platform = _FakeAppLinkPlatform();
    final service = AppLinkService(platform: platform, commands: commands);
    const coldTarget = 'https://example.com/cold.zip';
    const runningTarget = 'https://example.com/running.zip';

    await service.initialize(
      launchArguments: <String>['--ignored', _linkFor(coldTarget)],
    );
    platform.emit(_linkFor(runningTarget));
    expect(openedTargets, isEmpty);

    await commands.markNavigationReady();

    expect(openedTargets, <String>[coldTarget, runningTarget]);
    service.onClose();
    await Future<void>.delayed(Duration.zero);
    expect(platform.disposed, isTrue);
  });
}

String _linkFor(String target) => Uri(
  scheme: 'downpeed',
  host: 'download',
  queryParameters: <String, String>{'url': target},
).toString();

class _FakeAppLinkPlatform implements AppLinkPlatform {
  ValueChanged<String>? _onUri;
  bool disposed = false;

  @override
  Future<void> listen(ValueChanged<String> onUri) async {
    _onUri = onUri;
  }

  void emit(String uri) => _onUri?.call(uri);

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
