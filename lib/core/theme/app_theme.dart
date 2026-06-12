import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Hivora "Hive" Material theme — redesign 2026.
///
/// Key shifts from the old pastel-glassmorphism theme:
///   • Tighter radii: cards 14 (was 28), controls 10 — crisp, not bubbly.
///   • Hairline borders + a whisper of shadow instead of heavy soft cards.
///   • Warm-paper canvas (#F4F3EF) instead of lavender-grey.
///   • Sora is reserved for display/headings; IBM Plex Sans drives dense UI,
///     IBM Plex Mono renders issue IDs & numeric metrics.
///   • Honey-amber accent used for highlights/active/focus.
abstract final class AppTheme {
  static const radiusCard = 14.0;
  static const radiusControl = 10.0;
  static const radiusPill = 999.0;

  static const fontBrand = 'Sora';       // headings, wordmark
  static const fontUi = 'IBMPlexSans';   // body / dense UI
  static const fontMono = 'IBMPlexMono'; // ids, metrics

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontUi,
    );
    final text = base.textTheme
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontFamily: fontBrand,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: AppColors.ink,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontFamily: fontBrand,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: text,
      dividerColor: AppColors.hairline,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: AppColors.hairline),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(44, 44),
          side: const BorderSide(color: AppColors.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.navy),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: border(AppColors.hairline),
        enabledBorder: border(AppColors.hairline),
        focusedBorder: border(AppColors.accent, 1.5),
        hintStyle: const TextStyle(color: AppColors.inkFaint),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceMuted,
        side: const BorderSide(color: AppColors.hairline2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 11),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentSoft,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        backgroundColor: AppColors.rail,
        indicatorColor: Color(0x14FFFFFF),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
      ),
    );
  }
}
