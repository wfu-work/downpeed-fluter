import 'package:flutter/foundation.dart';
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
    final baseTextTheme =
        Typography.material2021(platform: defaultTargetPlatform).black.apply(
          bodyColor: colors.text,
          displayColor: colors.text,
          fontFamily: '.AppleSystemUIFont',
          fontFamilyFallback: _fontFallback,
        );
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 22,
        height: 1.22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.45,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.35,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.08,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 13,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: '.AppleSystemUIFont',
      fontFamilyFallback: _fontFallback,
      textTheme: textTheme,
      scaffoldBackgroundColor: colors.workspace,
      canvasColor: colors.surface,
      dividerColor: colors.border,
      hoverColor: colors.surfaceSubtle,
      focusColor: colors.accent.withValues(alpha: 0.14),
      splashFactory: NoSplash.splashFactory,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      iconTheme: IconThemeData(
        color: colors.textSecondary,
        size: DownpeedThemeTokens.iconSize,
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: DownpeedThemeTokens.toolbarHeight,
        backgroundColor: colors.workspace,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: colors.surfaceRaised,
        hintStyle: TextStyle(color: colors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        border: _inputBorder(colors.border),
        enabledBorder: _inputBorder(colors.border),
        focusedBorder: _inputBorder(colors.accent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, DownpeedThemeTokens.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, DownpeedThemeTokens.controlHeight),
          foregroundColor: colors.text,
          side: BorderSide(color: colors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          maximumSize: const Size(36, 36),
          foregroundColor: colors.textSecondary,
          hoverColor: colors.surfaceSubtle,
          highlightColor: colors.surfaceSubtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
        side: BorderSide(color: colors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
          side: BorderSide(color: colors.border),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.text,
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusSmall),
        ),
        textStyle: TextStyle(color: colors.workspace, fontSize: 12),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
    borderSide: BorderSide(color: color),
  );
}
