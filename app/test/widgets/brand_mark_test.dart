import 'package:downpeed_flutter/app/widgets/brand_mark.dart';
import 'package:downpeed_flutter/configs/theme/app_theme.dart';
import 'package:downpeed_flutter/configs/theme/downpeed_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand mark follows light and dark theme foreground colors', (
    tester,
  ) async {
    final lightPixel = await _renderMark(tester, AppTheme.light);
    final darkPixel = await _renderMark(tester, AppTheme.dark);

    expect(lightPixel, DownpeedThemeTokens.colorsFor(Brightness.light).text);
    expect(darkPixel, DownpeedThemeTokens.colorsFor(Brightness.dark).text);
  });
}

Future<Color> _renderMark(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    Theme(
      data: theme,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: DownpeedBrandMark(size: 100)),
      ),
    ),
  );
  await tester.pump();

  final customPaint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(DownpeedBrandMark),
      matching: find.byType(CustomPaint),
    ),
  );
  return (customPaint.painter as dynamic).color as Color;
}
