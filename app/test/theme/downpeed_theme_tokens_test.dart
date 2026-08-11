import 'package:downpeed_flutter/configs/theme/downpeed_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme keeps a quiet neutral hierarchy and ink accent', () {
    final colors = DownpeedThemeTokens.colorsFor(Brightness.light);

    expect(colors.workspace, const Color(0xFFFCFCFA));
    expect(colors.sidebar, const Color(0xFFF2F2EF));
    expect(colors.accent, const Color(0xFF20201E));
    expect(
      colors.workspace.computeLuminance(),
      greaterThan(colors.sidebar.computeLuminance()),
    );
  });

  test('dark theme preserves contrast without a pure black surface', () {
    final colors = DownpeedThemeTokens.colorsFor(Brightness.dark);

    expect(colors.workspace, const Color(0xFF1E1E1C));
    expect(colors.surfaceRaised, const Color(0xFF252523));
    expect(colors.text, const Color(0xFFF1F1ED));
  });
}
