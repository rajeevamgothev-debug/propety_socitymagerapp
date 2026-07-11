import 'package:flutter/material.dart';

import '../models/app_models.dart';

class AppTheme {
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryHover = Color(0xFF4338CA);
  static const Color primarySoft = Color(0xFFEEF2FF);
  static const Color primaryTone = Color(0xFFC7D2FE);

  static const Color secondary = Color(0xFFF59E0B);
  static const Color secondaryHover = Color(0xFFD97706);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF3F4F6);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFD1D5DB);
  static const Color borderSoft = Color(0xFFF3F4F6);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;

  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(18, 22, 18, 28);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      error: Color(0xFFDC2626),
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
    ),
    scaffoldBackgroundColor: background,
    canvasColor: background,
    dividerColor: border,
    shadowColor: const Color(0x120F172A),
    visualDensity: VisualDensity.standard,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.214,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        height: 1.273,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        height: 1.333,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        height: 1.333,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.467,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.462,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.417,
        fontWeight: FontWeight.w400,
        color: textMuted,
        letterSpacing: 0,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.286,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        height: 1.308,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.273,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18,
        height: 1.556,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFFFFCF8),
      hintStyle: const TextStyle(
        color: textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: const TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: textMuted,
      suffixIconColor: textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: textPrimary,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      modalBarrierColor: Color(0x660B1220),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 8,
      focusElevation: 8,
      hoverElevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF93C5FD),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.429,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textSecondary,
        disabledForegroundColor: textMuted,
        side: const BorderSide(color: border, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.429,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.429,
        ),
      ),
    ),
  );

  static Color toneColor(UiTone tone) {
    return switch (tone) {
      UiTone.brand => primary,
      UiTone.success => const Color(0xFF10B981),
      UiTone.warning => const Color(0xFFF59E0B),
      UiTone.danger => const Color(0xFFEF4444),
      UiTone.neutral => const Color(0xFF475569),
    };
  }

  static Color toneContainer(UiTone tone) {
    return switch (tone) {
      UiTone.brand => primarySoft,
      UiTone.success => const Color(0xFFD1FAE5),
      UiTone.warning => const Color(0xFFFEF3C7),
      UiTone.danger => const Color(0xFFFEE2E2),
      UiTone.neutral => const Color(0xFFF2F4F7),
    };
  }

  static Color toneSoft(UiTone tone) {
    return switch (tone) {
      UiTone.brand => primarySoft,
      UiTone.success => const Color(0xFFECFDF5),
      UiTone.warning => const Color(0xFFFFFBEB),
      UiTone.danger => const Color(0xFFFEF2F2),
      UiTone.neutral => surfaceMuted,
    };
  }
}
