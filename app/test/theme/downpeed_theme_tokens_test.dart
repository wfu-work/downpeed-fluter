import 'package:downpeed_flutter/configs/theme/downpeed_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme keeps a quiet neutral hierarchy and ink accent', () {
    final colors = DownpeedThemeTokens.colorsFor(Brightness.light);

    expect(colors.workspace, const Color(0xFFF9F9F7));
    expect(colors.sidebar, const Color(0xFFEFEFEB));
    expect(colors.accent, const Color(0xFF242421));
    expect(DownpeedThemeTokens.controlHeight, 32);
    expect(DownpeedThemeTokens.iconSize, 15);
    expect(
      colors.workspace.computeLuminance(),
      greaterThan(colors.sidebar.computeLuminance()),
    );
  });

  test('dark theme preserves contrast without a pure black surface', () {
    final colors = DownpeedThemeTokens.colorsFor(Brightness.dark);

    expect(colors.workspace, const Color(0xFF1D1D1B));
    expect(colors.surfaceRaised, const Color(0xFF252523));
    expect(colors.text, const Color(0xFFEDEDE8));
  });
}
