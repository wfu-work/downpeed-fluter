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

  test('dark theme matches the Codex neutral surface hierarchy', () {
    final colors = DownpeedThemeTokens.colorsFor(Brightness.dark);

    expect(colors.workspace, const Color(0xFF131313));
    expect(colors.sidebar, const Color(0xFF1A1A1A));
    expect(colors.sidebarSelection, const Color(0xFF2A2A2A));
    expect(colors.surface, const Color(0xFF1F1F1F));
    expect(colors.surfaceRaised, const Color(0xFF222222));
    expect(colors.border, const Color(0xFF3A3A3A));
    expect(colors.borderStrong, const Color(0xFF404040));
    expect(colors.text, const Color(0xFFDBDBDB));
    expect(colors.textSecondary, const Color(0xFFAFAFAF));
    expect(colors.textMuted, const Color(0xFF767676));
    expect(colors.accent, const Color(0xFFFFFFFF));
    expect(colors.onAccent, const Color(0xFF131313));
  });
}
