import 'package:flutter/material.dart';

class DownpeedThemeTokens {
  const DownpeedThemeTokens._();

  static const radiusSmall = 4.0;
  static const radius = 6.0;
  static const radiusLarge = 8.0;
  static const radiusPill = 999.0;

  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const space = 12.0;
  static const spaceMd = 16.0;
  static const spaceLg = 20.0;
  static const spaceXl = 28.0;
  static const space2xl = 40.0;

  static const compactPagePadding = 18.0;
  static const pagePadding = 24.0;
  static const sidebarMinWidth = 200.0;
  static const sidebarWidth = 236.0;
  static const sidebarMaxWidth = 360.0;
  static const sidebarCollapsedWidth = 52.0;
  static const toolbarHeight = 46.0;
  static const controlHeight = 34.0;
  static const iconSize = 16.0;

  static DownpeedResolvedColors colorsFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const DownpeedResolvedColors(
        workspace: Color(0xFF1E1E1C),
        sidebar: Color(0xFF171715),
        sidebarSelection: Color(0xFF2A2A27),
        surface: Color(0xFF242422),
        surfaceSubtle: Color(0xFF2B2B28),
        surfaceRaised: Color(0xFF252523),
        border: Color(0xFF343431),
        borderStrong: Color(0xFF4A4A45),
        text: Color(0xFFF1F1ED),
        textSecondary: Color(0xFFB6B6B0),
        textMuted: Color(0xFF85857F),
        accent: Color(0xFFF1F1ED),
        onAccent: Color(0xFF1B1B19),
        success: Color(0xFF56A66F),
        warning: Color(0xFFD09A52),
        danger: Color(0xFFD8716B),
        track: Color(0xFF444440),
      );
    }
    return const DownpeedResolvedColors(
      workspace: Color(0xFFFCFCFA),
      sidebar: Color(0xFFF2F2EF),
      sidebarSelection: Color(0xFFE4E4E0),
      surface: Color(0xFFF7F7F4),
      surfaceSubtle: Color(0xFFEDEDEA),
      surfaceRaised: Color(0xFFFFFFFF),
      border: Color(0xFFE2E2DE),
      borderStrong: Color(0xFFCBCBC5),
      text: Color(0xFF20201E),
      textSecondary: Color(0xFF666661),
      textMuted: Color(0xFF92928B),
      accent: Color(0xFF20201E),
      onAccent: Color(0xFFFAFAF8),
      success: Color(0xFF2F8653),
      warning: Color(0xFFA66B21),
      danger: Color(0xFFB94A43),
      track: Color(0xFFD6D6D1),
    );
  }
}

class DownpeedResolvedColors {
  const DownpeedResolvedColors({
    required this.workspace,
    required this.sidebar,
    required this.sidebarSelection,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.track,
  });

  final Color workspace;
  final Color sidebar;
  final Color sidebarSelection;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color track;
}

extension DownpeedThemeContext on BuildContext {
  DownpeedResolvedColors get downpeedColors =>
      DownpeedThemeTokens.colorsFor(Theme.of(this).brightness);
}
