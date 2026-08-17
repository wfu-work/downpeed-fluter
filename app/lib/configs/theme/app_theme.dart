import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'downpeed_theme_tokens.dart';

class DownpeedScrollBehavior extends MaterialScrollBehavior {
  const DownpeedScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class AppTheme {
  const AppTheme._();

  static const _fontFallback = <String>[
    'SF Pro Text',
    'PingFang SC',
    'Helvetica Neue',
    'Segoe UI',
    'Noto Sans CJK SC',
    'Microsoft YaHei',
    'sans-serif',
  ];

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final colors = DownpeedThemeTokens.colorsFor(brightness);
    final isDark = brightness == Brightness.dark;
    final textTheme = _textTheme(
      colors.text,
    ).apply(fontFamilyFallback: _fontFallback);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          onPrimary: colors.onAccent,
          error: colors.danger,
          surface: colors.surface,
          onSurface: colors.text,
          outline: colors.borderStrong,
          outlineVariant: colors.border,
          surfaceContainerLowest: colors.workspace,
          surfaceContainerLow: colors.surface,
          surfaceContainer: colors.surfaceSubtle,
          surfaceContainerHigh: colors.surfaceRaised,
        );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
      borderSide: BorderSide(color: colors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: '.AppleSystemUIFont',
      fontFamilyFallback: _fontFallback,
      textTheme: textTheme,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      scaffoldBackgroundColor: colors.workspace,
      canvasColor: colors.surface,
      dividerColor: colors.border,
      disabledColor: colors.textMuted,
      hoverColor: colors.surfaceSubtle,
      focusColor: colors.sidebarSelection,
      splashFactory: NoSplash.splashFactory,
      iconTheme: IconThemeData(
        color: colors.textSecondary,
        size: DownpeedThemeTokens.iconSize,
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: DownpeedThemeTokens.toolbarHeight,
        backgroundColor: colors.workspace,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: colors.text),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.border, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: colors.surfaceRaised,
        labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: colors.text),
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        prefixIconColor: colors.textMuted,
        suffixIconColor: colors.textSecondary,
        prefixIconConstraints: const BoxConstraints.tightFor(
          width: DownpeedThemeTokens.controlHeight,
          height: DownpeedThemeTokens.controlHeight,
        ),
        suffixIconConstraints: const BoxConstraints.tightFor(
          width: DownpeedThemeTokens.controlHeight,
          height: DownpeedThemeTokens.controlHeight,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.borderStrong, width: 1.25),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, DownpeedThemeTokens.controlHeight),
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.surfaceSubtle,
          disabledForegroundColor: colors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          shape: controlShape,
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, DownpeedThemeTokens.controlHeight),
          foregroundColor: colors.text,
          disabledForegroundColor: colors.textMuted,
          side: BorderSide(color: colors.border),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(36, DownpeedThemeTokens.controlHeight),
          foregroundColor: colors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          fixedSize: const Size.square(DownpeedThemeTokens.touchTarget),
          iconSize: DownpeedThemeTokens.iconSize,
          foregroundColor: colors.textSecondary,
          hoverColor: colors.sidebarSelection,
          highlightColor: colors.sidebarSelection,
          shape: controlShape,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.text,
        selectedColor: colors.text,
        selectedTileColor: colors.sidebarSelection,
        titleTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: colors.textSecondary,
        ),
        minLeadingWidth: 18,
        horizontalTitleGap: 9,
        minVerticalPadding: 5,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        shape: controlShape,
      ),
      checkboxTheme: CheckboxThemeData(
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        side: BorderSide(color: colors.borderStrong),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(colors.onAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, DownpeedThemeTokens.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          iconSize: const WidgetStatePropertyAll(DownpeedThemeTokens.iconSize),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.sidebarSelection
                : colors.surfaceRaised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.text
                : colors.textSecondary,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
          shape: WidgetStatePropertyAll(controlShape),
        ),
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.textMuted;
          if (states.contains(WidgetState.selected)) return colors.onAccent;
          return isDark ? colors.textSecondary : colors.surfaceRaised;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.surfaceSubtle;
          }
          return states.contains(WidgetState.selected)
              ? colors.accent
              : colors.surfaceSubtle;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : colors.borderStrong,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(1),
        overlayColor: WidgetStatePropertyAll(
          colors.sidebarSelection.withValues(alpha: 0.72),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: colors.textSecondary,
        collapsedIconColor: colors.textMuted,
        textColor: colors.text,
        collapsedTextColor: colors.textSecondary,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 56,
        elevation: 0,
        backgroundColor: colors.sidebar,
        indicatorColor: colors.sidebarSelection,
        indicatorShape: controlShape,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.text
                : colors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: DownpeedThemeTokens.iconSize,
            color: states.contains(WidgetState.selected)
                ? colors.text
                : colors.textSecondary,
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
        textStyle: textTheme.bodyMedium,
        menuPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
          side: BorderSide(color: colors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: colors.surfaceRaised,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
          side: BorderSide(color: colors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
          side: BorderSide(color: colors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 420),
        showDuration: const Duration(seconds: 3),
        textStyle: textTheme.labelSmall?.copyWith(color: colors.onAccent),
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusSmall),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      headlineMedium: TextStyle(
        color: color,
        fontSize: 21,
        height: 1.24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        color: color,
        fontSize: DownpeedThemeTokens.textHeading,
        height: 1.28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: color,
        fontSize: DownpeedThemeTokens.textHeading,
        height: 1.28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: color,
        fontSize: 13.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        color: color,
        fontSize: 12.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        color: color,
        fontSize: DownpeedThemeTokens.textBodyLarge,
        height: 1.46,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        color: color,
        fontSize: DownpeedThemeTokens.textBody,
        height: 1.42,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        color: color,
        fontSize: DownpeedThemeTokens.textCaption,
        height: 1.4,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      labelLarge: TextStyle(
        color: color,
        fontSize: DownpeedThemeTokens.textLabel,
        height: 1.32,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        color: color,
        fontSize: DownpeedThemeTokens.textCaption,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        color: color,
        fontSize: DownpeedThemeTokens.textMicro,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );
  }
}
