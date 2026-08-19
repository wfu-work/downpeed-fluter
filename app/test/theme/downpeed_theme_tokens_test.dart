import 'package:downpeed_flutter/configs/theme/downpeed_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme keeps a quiet green-gray hierarchy', () {
    final colors = DownpeedThemeTokens.colorsFor(Brightness.light);

    expect(colors.workspace, const Color(0xFFF3F5F3));
    expect(colors.sidebar, const Color(0xFFE8ECE9));
    expect(colors.accent, const Color(0xFF28322C));
    expect(DownpeedThemeTokens.controlHeight, 32);
    expect(DownpeedThemeTokens.iconSize, 15);
    expect(
      colors.workspace.computeLuminance(),
      greaterThan(colors.sidebar.computeLuminance()),
    );
  });

  test('dark theme uses graphite surfaces and a cool accent', () {
    final colors = DownpeedThemeTokens.colorsFor(Brightness.dark);

    expect(colors.workspace, const Color(0xFF16191D));
    expect(colors.workspaceLower, const Color(0xFF101417));
    expect(colors.sidebar, const Color(0xFF1E2328));
    expect(colors.sidebarLower, const Color(0xFF191E23));
    expect(colors.sidebarSelection, const Color(0xFF34414A));
    expect(colors.surface, const Color(0xFF20262B));
    expect(colors.surfaceSubtle, const Color(0xFF2A3238));
    expect(colors.surfaceRaised, const Color(0xFF283036));
    expect(colors.taskList, const Color(0xFF20272C));
    expect(colors.taskListLower, const Color(0xFF1A2025));
    expect(colors.taskListHeader, const Color(0xFF263038));
    expect(colors.taskRow, const Color(0xFF283138));
    expect(colors.taskRowHover, const Color(0xFF323D45));
    expect(colors.taskRowSelected, const Color(0xFF38464E));
    expect(colors.taskRowBorder, const Color(0xFF3F4B53));
    expect(colors.border, const Color(0xFF3C474E));
    expect(colors.borderStrong, const Color(0xFF6D7C87));
    expect(colors.text, const Color(0xFFF4F7F8));
    expect(colors.textSecondary, const Color(0xFFC6D0D5));
    expect(colors.textMuted, const Color(0xFF99A5AB));
    expect(colors.accent, const Color(0xFFB7D6E4));
    expect(colors.onAccent, const Color(0xFF142026));
    expect(colors.track, const Color(0xFF53626A));
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
