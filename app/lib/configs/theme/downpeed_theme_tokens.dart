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
  static const toolbarHeight = 44.0;
  static const controlHeight = 32.0;
  static const touchTarget = 32.0;
  static const iconSize = 15.0;

  static const textHeading = 19.0;
  static const textTitle = 16.0;
  static const textBodyLarge = 14.0;
  static const textBody = 13.0;
  static const textLabel = 12.5;
  static const textCaption = 11.5;
  static const textMicro = 10.5;

  static DownpeedResolvedColors colorsFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const DownpeedResolvedColors(
        workspace: Color(0xFF1D1D1B),
        sidebar: Color(0xFF171716),
        sidebarSelection: Color(0xFF2A2A28),
        surface: Color(0xFF232321),
        surfaceSubtle: Color(0xFF292927),
        surfaceRaised: Color(0xFF252523),
        border: Color(0xFF353532),
        borderStrong: Color(0xFF494945),
        text: Color(0xFFEDEDE8),
        textSecondary: Color(0xFFB1B1AA),
        textMuted: Color(0xFF81817A),
        accent: Color(0xFFEDEDE8),
        onAccent: Color(0xFF1B1B19),
        success: Color(0xFF56A66F),
        warning: Color(0xFFD09A52),
        danger: Color(0xFFD8716B),
        track: Color(0xFF41413D),
      );
    }
    return const DownpeedResolvedColors(
      workspace: Color(0xFFF9F9F7),
      sidebar: Color(0xFFEFEFEB),
      sidebarSelection: Color(0xFFE1E1DC),
      surface: Color(0xFFF4F4F1),
      surfaceSubtle: Color(0xFFECECE8),
      surfaceRaised: Color(0xFFFCFCFA),
      border: Color(0xFFDEDED9),
      borderStrong: Color(0xFFC8C8C1),
      text: Color(0xFF242421),
      textSecondary: Color(0xFF62625D),
      textMuted: Color(0xFF898983),
      accent: Color(0xFF242421),
      onAccent: Color(0xFFF9F9F7),
      success: Color(0xFF2F8653),
      warning: Color(0xFFA66B21),
      danger: Color(0xFFB94A43),
      track: Color(0xFFD4D4CE),
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
