import 'package:flutter/material.dart';

class DownpeedThemeTokens {
  const DownpeedThemeTokens._();

  static const radiusSmall = 4.0;
  static const radius = 6.0;
  static const radiusLarge = 8.0;
  static const radiusPill = 999.0;
  static const taskRowRadius = 8.0;

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
  static const sidebarNavigationHeight = 40.0;
  static const sidebarIconSize = 17.0;
  static const toolbarHeight = 44.0;
  static const controlHeight = 32.0;
  static const touchTarget = 32.0;
  static const iconSize = 15.0;
  static const taskStatusIconSize = 17.0;

  static const textHeading = 24.0;
  static const textSectionHeading = 19.0;
  static const textTitle = 16.0;
  static const textBodyLarge = 14.0;
  static const textBody = 13.0;
  static const textLabel = 12.5;
  static const textCaption = 11.5;
  static const textMicro = 10.5;

  static DownpeedResolvedColors colorsFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const DownpeedResolvedColors(
        workspace: Color(0xFF16191D),
        workspaceLower: Color(0xFF101417),
        sidebar: Color(0xFF1E2328),
        sidebarLower: Color(0xFF191E23),
        sidebarSelection: Color(0xFF34414A),
        surface: Color(0xFF20262B),
        surfaceSubtle: Color(0xFF2A3238),
        surfaceRaised: Color(0xFF283036),
        taskList: Color(0xFF20272C),
        taskListLower: Color(0xFF1A2025),
        taskListHeader: Color(0xFF263038),
        taskRow: Color(0xFF283138),
        taskRowHover: Color(0xFF323D45),
        taskRowSelected: Color(0xFF38464E),
        taskRowBorder: Color(0xFF3F4B53),
        border: Color(0xFF3C474E),
        borderStrong: Color(0xFF6D7C87),
        text: Color(0xFFF4F7F8),
        textSecondary: Color(0xFFC6D0D5),
        textMuted: Color(0xFF99A5AB),
        accent: Color(0xFFB7D6E4),
        onAccent: Color(0xFF142026),
        success: Color(0xFF5AC88A),
        warning: Color(0xFFD4A15A),
        danger: Color(0xFFE27473),
        track: Color(0xFF53626A),
      );
    }
    return const DownpeedResolvedColors(
      workspace: Color(0xFFF3F5F3),
      workspaceLower: Color(0xFFF1F4F1),
      sidebar: Color(0xFFE8ECE9),
      sidebarLower: Color(0xFFE4EAE6),
      sidebarSelection: Color(0xFFDDE6DF),
      surface: Color(0xFFEEF2EF),
      surfaceSubtle: Color(0xFFE7ECE8),
      surfaceRaised: Color(0xFFFFFFFF),
      taskList: Color(0xFFEEF2F0),
      taskListLower: Color(0xFFE7EDE9),
      taskListHeader: Color(0xFFE8EEEA),
      taskRow: Color(0xFFFFFFFF),
      taskRowHover: Color(0xFFF0F5F1),
      taskRowSelected: Color(0xFFE1EAE3),
      taskRowBorder: Color(0xFFD6E0D8),
      border: Color(0xFFE1E7E2),
      borderStrong: Color(0xFFC2CCC4),
      text: Color(0xFF202622),
      textSecondary: Color(0xFF5E6861),
      textMuted: Color(0xFF89938C),
      accent: Color(0xFF28322C),
      onAccent: Color(0xFFF3F5F3),
      success: Color(0xFF2C8A58),
      warning: Color(0xFFA97621),
      danger: Color(0xFFB94B44),
      track: Color(0xFFD4DED7),
    );
  }
}

class DownpeedResolvedColors {
  const DownpeedResolvedColors({
    required this.workspace,
    required this.workspaceLower,
    required this.sidebar,
    required this.sidebarLower,
    required this.sidebarSelection,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.taskList,
    required this.taskListLower,
    required this.taskListHeader,
    required this.taskRow,
    required this.taskRowHover,
    required this.taskRowSelected,
    required this.taskRowBorder,
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
  final Color workspaceLower;
  final Color sidebar;
  final Color sidebarLower;
  final Color sidebarSelection;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceRaised;
  final Color taskList;
  final Color taskListLower;
  final Color taskListHeader;
  final Color taskRow;
  final Color taskRowHover;
  final Color taskRowSelected;
  final Color taskRowBorder;
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

  BoxDecoration get downpeedWorkspaceDecoration {
    final colors = downpeedColors;
    if (Theme.of(this).brightness == Brightness.light) {
      return BoxDecoration(color: colors.workspace);
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.workspace, colors.workspaceLower],
        stops: const [0.08, 1],
      ),
    );
  }

  BoxDecoration get downpeedSidebarDecoration {
    final colors = downpeedColors;
    if (Theme.of(this).brightness == Brightness.light) {
      return BoxDecoration(color: colors.sidebar);
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.sidebar, colors.sidebarLower],
      ),
    );
  }

  BoxDecoration get downpeedTaskListDecoration {
    final colors = downpeedColors;
    if (Theme.of(this).brightness == Brightness.light) {
      return BoxDecoration(color: colors.taskList);
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.taskList, colors.taskListLower],
      ),
    );
  }
}
