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

  test('dark theme uses the indigo workspace and midnight surfaces', () {
    final colors = DownpeedThemeTokens.colorsFor(Brightness.dark);

    expect(colors.workspace, const Color(0xFF28234F));
    expect(colors.workspaceLower, const Color(0xFF1B3152));
    expect(colors.sidebar, const Color(0xFF29244F));
    expect(colors.sidebarLower, const Color(0xFF1C3253));
    expect(colors.sidebarSelection, const Color(0xFF454064));
    expect(colors.surface, const Color(0xFF22273A));
    expect(colors.surfaceSubtle, const Color(0xFF32354D));
    expect(colors.surfaceRaised, const Color(0xFF2A2D42));
    expect(colors.taskList, const Color(0xFF262A45));
    expect(colors.taskListLower, const Color(0xFF1D304B));
    expect(colors.taskListHeader, const Color(0xFF2B2E4B));
    expect(colors.taskRow, const Color(0xFF292E4B));
    expect(colors.taskRowHover, const Color(0xFF323656));
    expect(colors.taskRowSelected, const Color(0xFF373657));
    expect(colors.taskRowBorder, const Color(0xFF424866));
    expect(colors.border, const Color(0xFF42465F));
    expect(colors.borderStrong, const Color(0xFF71768E));
    expect(colors.text, const Color(0xFFF1EFF4));
    expect(colors.textSecondary, const Color(0xFFC5C2CE));
    expect(colors.textMuted, const Color(0xFFA19EAE));
    expect(colors.accent, const Color(0xFFF5F3F8));
    expect(colors.onAccent, const Color(0xFF211D3B));
    expect(colors.track, const Color(0xFF50556D));
    expect(
      _contrastRatio(colors.textMuted, colors.surfaceSubtle),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(colors.borderStrong, colors.surfaceRaised),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrastRatio(colors.textMuted, colors.taskRow),
      greaterThanOrEqualTo(4.5),
    );
    expect(DownpeedThemeTokens.sidebarNavigationHeight, 40);
    expect(DownpeedThemeTokens.sidebarIconSize, 17);
    expect(DownpeedThemeTokens.taskStatusIconSize, 17);
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
