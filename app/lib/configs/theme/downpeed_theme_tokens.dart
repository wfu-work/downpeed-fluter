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
        workspace: Color(0xFF28234F),
        workspaceLower: Color(0xFF1B3152),
        sidebar: Color(0xFF29244F),
        sidebarLower: Color(0xFF1C3253),
        sidebarSelection: Color(0xFF454064),
        surface: Color(0xFF22273A),
        surfaceSubtle: Color(0xFF32354D),
        surfaceRaised: Color(0xFF2A2D42),
        taskList: Color(0xFF262A45),
        taskListLower: Color(0xFF1D304B),
        taskListHeader: Color(0xFF2B2E4B),
        taskRow: Color(0xFF292E4B),
        taskRowHover: Color(0xFF323656),
        taskRowSelected: Color(0xFF373657),
        taskRowBorder: Color(0xFF424866),
        border: Color(0xFF42465F),
        borderStrong: Color(0xFF71768E),
        text: Color(0xFFF1EFF4),
        textSecondary: Color(0xFFC5C2CE),
        textMuted: Color(0xFFA19EAE),
        accent: Color(0xFFF5F3F8),
        onAccent: Color(0xFF211D3B),
        success: Color(0xFF4EBB8C),
        warning: Color(0xFFD4A15A),
        danger: Color(0xFFE07175),
        track: Color(0xFF50556D),
      );
    }
    return const DownpeedResolvedColors(
      workspace: Color(0xFFF9F9F7),
      workspaceLower: Color(0xFFF9F9F7),
      sidebar: Color(0xFFEFEFEB),
      sidebarLower: Color(0xFFEFEFEB),
      sidebarSelection: Color(0xFFE1E1DC),
      surface: Color(0xFFF4F4F1),
      surfaceSubtle: Color(0xFFECECE8),
      surfaceRaised: Color(0xFFFCFCFA),
      taskList: Color(0xFFF2F4F2),
      taskListLower: Color(0xFFEAEFED),
      taskListHeader: Color(0xFFE9EEEC),
      taskRow: Color(0xFFFCFCFA),
      taskRowHover: Color(0xFFF0F3F1),
      taskRowSelected: Color(0xFFE7ECE9),
      taskRowBorder: Color(0xFFD4DDD9),
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
