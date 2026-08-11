import 'package:downpeed_flutter/configs/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the neutral desktop palette and restrained type hierarchy', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, const Color(0xFF20201E));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFCFCFA));
    expect(theme.textTheme.headlineSmall?.fontSize, 20);
    expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w600);
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
    expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
    expect(theme.textTheme.labelLarge?.fontWeight, FontWeight.w600);
  });
}
