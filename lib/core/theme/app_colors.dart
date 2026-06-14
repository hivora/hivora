import 'package:flutter/material.dart';

/// Hivora "Hive" design tokens — redesign 2026.
/// Navy nav-rail · warm-paper workspace · honey-amber signature accent.
///
/// Hex values are derived from an oklch model (constant L/C, varied hue) so
/// status & accent tints stay perceptually harmonious. The web prototype keeps
/// the live oklch(); these are the closest sRGB equivalents for Flutter.
abstract final class AppColors {
  // ---- brand & ink ----
  static const navy = Color(0xFF2D2B55); // primary action
  static const navyDeep = Color(0xFF1E1C3A);
  static const ink = Color(0xFF23223F); // primary text
  static const inkSoft = Color(0xFF6B6A85); // secondary text
  static const inkFaint = Color(0xFF9A99B0); // tertiary / hints

  // ---- workspace surfaces (warm paper, NOT the old pastel-lavender) ----
  static const canvas = Color(0xFFF4F3EF); // app background
  static const canvas2 = Color(0xFFEFEEE8); // recessed (board columns)
  static const surface = Color(0xFFFFFFFF); // cards
  static const surfaceMuted = Color(0xFFFAF9F6);
  static const hairline = Color(0xFFE7E5DE); // card borders
  static const hairline2 = Color(0xFFEFEDE6);

  // ---- nav rail (deep navy) ----
  static const rail = Color(0xFF211F3D);
  static const rail2 = Color(0xFF1A1830);
  static const railInk = Color(0xFFC9C7E0);
  static const railFaint = Color(0xFF807EA0);

  // ---- signature honey-amber accent (hue 70) ----
  static const accent = Color(0xFFD9A032); // oklch(.74 .135 70)
  static const accentStrong = Color(0xFFB9831F); // oklch(.66 .145 70)
  static const accentSoft = Color(0xFFF3E9D2); // oklch(.94 .045 70)
  static const accentLine = Color(0xFFE4CE96); // oklch(.86 .07 70)

  // ---- workflow status (varied hue, constant L/C ~ oklch .6 .13) ----
  static const stBacklog = Color(0xFF7E81AE); // hue 255, muted slate
  static const stTodo = Color(0xFF5B86D6); // hue 250
  static const stProgress = Color(0xFFC58A22); // hue 70 (honey)
  static const stReview = Color(0xFF9A6BD0); // hue 300
  static const stDone = Color(0xFF2FA06E); // hue 155

  // ---- priority ----
  static const priUrgent = Color(0xFFD9544B); // hue 22
  static const priHigh = Color(0xFFD98A2B); // hue 45
  static const priNormal = Color(0xFF5B86D6); // hue 250
  static const priLow = Color(0xFF9A99B0); // muted

  // ---- semantic ----
  static const danger = Color(0xFFD9544B);
  static const dangerSoft = Color(0xFFFBE7E4);
  static const success = Color(0xFF2FA06E);
  static const warning = Color(0xFFD9A032);

  // ---- compatibility aliases (migrate screens progressively) ----
  static const textPrimary = ink;
  static const textSecondary = inkSoft;
  static const textOnDark = Colors.white;
  static const navyDark = navyDeep;
  static const lavender = stReview; // closest purple equivalent
  static const background = canvas;
  static const backgroundEnd = canvas2;
  // pastel palette → warm tints matching the new paper canvas
  static const pastelBlue = Color(0xFFE9EEF8);
  static const pastelLavender = Color(0xFFEFEBF8);
  static const pastelPeach = Color(0xFFF3E9D2); // = accentSoft
  static const pastelMint = Color(0xFFE4F2EC);
  static const pastels = [pastelBlue, pastelLavender, pastelPeach, pastelMint];
  static Color pastelFor(int index) => pastels[index % pastels.length];
  // old accent names → new semantic equivalents
  static const accentOrange = accent;
  static const accentPurple = stReview;
  static const accentBlue = stTodo;
  static const accentTeal = stDone;

  /// Maps a workflow state to its signature colour. Accepts both canonical
  /// codes (`IN_PROGRESS`) and human/display variants (`In Progress`, `in-progress`)
  /// by normalising case and any space/underscore/hyphen separators first — so a
  /// column whose `states` carry display names still tints to the theme colour
  /// instead of silently falling through to the backlog slate.
  static Color stateColor(String state) =>
      switch (state.toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '')) {
        'TODO' => stTodo,
        'INPROGRESS' => stProgress,
        'INREVIEW' => stReview,
        'DONE' => stDone,
        'BACKLOG' => stBacklog,
        _ => stBacklog,
      };

  static Color priorityColor(String priority) =>
      switch (priority.toUpperCase()) {
        // Backend Issue.Priority enum.
        'SHOWSTOPPER' || 'CRITICAL' => priUrgent,
        'MAJOR' => priHigh,
        'NORMAL' => priNormal,
        'MINOR' => priLow,
        // Legacy aliases.
        'URGENT' => priUrgent,
        'HIGH' => priHigh,
        'LOW' => priLow,
        _ => priLow,
      };

  /// Soft tint of any base color for badge / chip backgrounds (~oklch .96 tint).
  static Color soft(Color base) => Color.alphaBlend(base.withValues(alpha: 0.12), surface);
}
