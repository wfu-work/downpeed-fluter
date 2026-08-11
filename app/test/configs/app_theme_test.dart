import 'package:downpeed_flutter/configs/theme/app_theme.dart';
import 'package:downpeed_flutter/configs/theme/downpeed_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the neutral desktop palette and restrained type hierarchy', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, const Color(0xFF242421));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF9F9F7));
    expect(theme.textTheme.headlineSmall?.fontSize, 19);
    expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w600);
    expect(theme.textTheme.bodyMedium?.fontSize, 13);
    expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
    expect(theme.textTheme.labelLarge?.fontSize, 12.5);
    expect(theme.textTheme.labelLarge?.fontWeight, FontWeight.w500);
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve({}),
      const Size(48, DownpeedThemeTokens.controlHeight),
    );
    expect(
      theme.iconButtonTheme.style?.fixedSize?.resolve({}),
      const Size.square(DownpeedThemeTokens.touchTarget),
    );
    expect(
      theme.iconButtonTheme.style?.iconSize?.resolve({}),
      DownpeedThemeTokens.iconSize,
    );
  });
}
