import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/domains/engine_info.dart';
import 'package:downpeed_flutter/main.dart';
import 'package:downpeed_flutter/configs/theme/downpeed_icons.dart';
import 'package:downpeed_flutter/configs/theme/downpeed_theme_tokens.dart';
import 'package:downpeed_flutter/services/app_service.dart';
import 'package:downpeed_flutter/services/engine_service.dart';
import 'package:downpeed_flutter/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/stub_engine_client.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('collapses, expands, and resizes the desktop sidebar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _registerOnlineEngine();

    await tester.pumpWidget(
      const DownpeedApp(initialThemeMode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();

    expect(find.text('Downpeed'), findsNothing);
    expect(
      find.byKey(const ValueKey('sidebar-toggle-expanded')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sidebar-resize-handle')), findsOneWidget);
    final selectedTaskMenu = find.byKey(const ValueKey('sidebar-filter-0'));
    expect(
      find.descendant(
        of: selectedTaskMenu,
        matching: find.byKey(const ValueKey('sidebar-selected-indicator')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: selectedTaskMenu,
        matching: find.byKey(const ValueKey('sidebar-count-badge')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sidebar-theme-toggle')),
        matching: find.byIcon(DownpeedIcons.lightTheme),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('切换到浅色模式'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sidebar-theme-toggle')));
    await tester.pumpAndSettle();

    expect(AppService.to.themeMode.value, ThemeMode.light);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sidebar-theme-toggle')),
        matching: find.byIcon(DownpeedIcons.darkTheme),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('切换到深色模式'), findsOneWidget);
    final initialWidth = tester
        .getSize(find.byKey(const ValueKey('sidebar-pane')))
        .width;

    await tester.tap(find.byKey(const ValueKey('sidebar-toggle-expanded')));
    await tester.pump();

    final collapsedWidth = tester
        .getSize(find.byKey(const ValueKey('sidebar-pane')))
        .width;
    expect(collapsedWidth, lessThan(initialWidth));
    expect(find.byKey(const ValueKey('sidebar-resize-handle')), findsNothing);
    expect(find.byKey(const ValueKey('sidebar-theme-toggle')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sidebar-toggle-collapsed')));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('sidebar-resize-handle')),
      const Offset(48, 0),
    );
    await tester.pump();

    final resizedWidth = tester
        .getSize(find.byKey(const ValueKey('sidebar-pane')))
        .width;
    expect(resizedWidth, closeTo(initialWidth + 48, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens settings and keeps task navigation available', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _registerOnlineEngine();

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar-settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    final settingsSubtitle = tester.widget<Text>(find.text('管理界面与本机偏好。'));
    expect(settingsSubtitle.maxLines, 1);
    expect(settingsSubtitle.overflow, TextOverflow.ellipsis);
    expect(
      find.byKey(const ValueKey('settings-theme-control')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-language-control')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-appearance-note')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-logo-light-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-logo-dark-preview')),
      findsOneWidget,
    );
    expect(
      _brandMarkColor(tester, const ValueKey('settings-logo-light-mark')),
      DownpeedThemeTokens.colorsFor(Brightness.light).text,
    );
    expect(
      _brandMarkColor(tester, const ValueKey('settings-logo-dark-mark')),
      DownpeedThemeTokens.colorsFor(Brightness.dark).text,
    );
    expect(find.text('外观偏好仅影响当前设备'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-navigation')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-nav-appearance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-nav-notifications')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-nav-about')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-nav-workspace')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-sidebar-expanded')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-theme-control')), findsNothing);
    expect(
      find.byKey(const ValueKey('settings-appearance-note')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('settings-workspace-note')),
      findsOneWidget,
    );
    expect(find.text('布局会随窗口宽度自动适应'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-nav-notifications')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-completion-notifications')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-new-download-shortcut')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-notifications-note')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('settings-completion-notifications')),
    );
    await tester.pump();
    expect(PreferencesService.to.completionNotificationsEnabled.value, isFalse);

    await tester.tap(find.byKey(const ValueKey('settings-nav-engine')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-engine-refresh')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-engine-note')), findsOneWidget);
    expect(find.text('下载任务由本机引擎处理'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-nav-about')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-app-version')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-about-engine-version')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-open-licenses')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-about-note')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-open-licenses')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-about-note')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-back-to-tasks')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-page')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sidebar-filter-1')));
    await tester.pumpAndSettle();
    expect(find.text('下载任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact settings uses menu and detail navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _registerOnlineEngine();

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-navigation')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-theme-control')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-nav-appearance')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-theme-control')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-appearance-note')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-logo-light-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-logo-dark-preview')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-navigation')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-compact-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-navigation')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-theme-control')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-nav-workspace')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-workspace-note')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-appearance-note')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('settings-compact-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-navigation')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-nav-notifications')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-completion-notifications')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-notifications-note')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('settings-compact-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-navigation')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-nav-engine')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-engine-note')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-workspace-note')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-compact-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-navigation')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-nav-about')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-app-version')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-about-note')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-compact-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-navigation')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-compact-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-page')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new settings remain usable at 200 percent text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await _registerOnlineEngine();

    await tester.pumpWidget(const DownpeedApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-nav-appearance')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-logo-dark-preview')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.byKey(const ValueKey('settings-logo-light-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-logo-dark-preview')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('settings-compact-back')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-nav-notifications')),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('settings-nav-notifications')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-notifications-note')),
      120,
      scrollable: find.byType(Scrollable).last,
    );

    expect(
      find.byKey(const ValueKey('settings-completion-notifications')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-notifications-note')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Color _brandMarkColor(WidgetTester tester, Key key) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint)),
  );
  return (paint.painter as dynamic).color as Color;
}

Future<void> _registerOnlineEngine() async {
  final engine = EngineService(client: const _ShellEngineClient());
  Get.put<EngineService>(engine, permanent: true);
  await engine.refresh();
}

class _ShellEngineClient extends StubEngineClient {
  const _ShellEngineClient();

  @override
  Future<EngineInfo> fetchInfo() async => const EngineInfo(
    name: 'Downpeed Engine',
    version: '0.1.0-test',
    commit: 'test',
    apiVersion: 'v1',
    goVersion: 'go1.26',
    os: 'darwin',
    arch: 'arm64',
  );

  @override
  Future<List<DownloadTask>> fetchTasks() async => const [];

  @override
  Stream<DownloadTaskEvent> watchTaskEvents() => const Stream.empty();
}
