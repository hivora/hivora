import 'package:flutter/material.dart';

/// Liquid-glass material tokens for the global search palette.
///
/// A 1:1 port of the light/dark token sets in `Design/search/app/search.css`
/// (§2 of `INTEGRATION.md`). Keep this file the single source of truth so the
/// Flutter surface stays in lockstep with the HTML reference.
@immutable
class SearchTokens {
  const SearchTokens({
    required this.tint,
    required this.tintStrong,
    required this.edge,
    required this.edgeSoft,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.hairline,
    required this.rowHover,
    required this.selTint,
    required this.selEdge,
    required this.glare,
    required this.scrim,
    required this.field,
    required this.markBg,
    required this.panelShadow,
  });

  /// Panel base tint (the translucent glass fill).
  final Color tint;

  /// Stronger tint for active chips / footer.
  final Color tintStrong;

  /// Bright specular edge (top-left of the rim).
  final Color edge;

  /// Dimmed specular edge (the rim's falloff).
  final Color edgeSoft;

  final Color ink; // primary text
  final Color inkSoft; // secondary text
  final Color inkFaint; // hints / faint glyphs

  final Color hairline; // 1px dividers / borders
  final Color rowHover; // hover lozenge fill
  final Color selTint; // selected-row lozenge fill
  final Color selEdge; // selected-row inset highlight
  final Color glare; // pointer-tracked sheen
  final Color scrim; // dim layer behind the panel
  final Color field; // inset field / kbd / icon tile fill
  final Color markBg; // matched-substring highlight background

  final List<BoxShadow> panelShadow;

  /// Light glass (`.gs-root`).
  static const light = SearchTokens(
    tint: Color.fromRGBO(252, 251, 248, 0.62),
    tintStrong: Color.fromRGBO(252, 251, 248, 0.80),
    edge: Color.fromRGBO(255, 255, 255, 0.85),
    edgeSoft: Color.fromRGBO(255, 255, 255, 0.35),
    ink: Color(0xFF23223F),
    inkSoft: Color(0xFF6B6A85),
    inkFaint: Color(0xFF9A99B0),
    hairline: Color.fromRGBO(35, 34, 63, 0.09),
    rowHover: Color.fromRGBO(35, 34, 63, 0.05),
    selTint: Color.fromRGBO(255, 255, 255, 0.78),
    selEdge: Color.fromRGBO(255, 255, 255, 0.95),
    glare: Color.fromRGBO(255, 255, 255, 0.55),
    scrim: Color.fromRGBO(22, 20, 45, 0.30),
    field: Color.fromRGBO(255, 255, 255, 0.55),
    // oklch(0.92 0.10 70 / 0.6) ≈ a pale honey wash.
    markBg: Color.fromRGBO(247, 224, 150, 0.65),
    panelShadow: [
      BoxShadow(
        color: Color.fromRGBO(20, 18, 45, 0.55),
        offset: Offset(0, 40),
        blurRadius: 90,
        spreadRadius: -30,
      ),
      BoxShadow(
        color: Color.fromRGBO(20, 18, 45, 0.30),
        offset: Offset(0, 8),
        blurRadius: 24,
        spreadRadius: -12,
      ),
    ],
  );

  /// Dark glass (`.gs-root[data-theme="dark"]`).
  static const dark = SearchTokens(
    tint: Color.fromRGBO(34, 32, 60, 0.58),
    tintStrong: Color.fromRGBO(38, 36, 66, 0.80),
    edge: Color.fromRGBO(255, 255, 255, 0.20),
    edgeSoft: Color.fromRGBO(255, 255, 255, 0.07),
    ink: Color(0xFFF2F1F8),
    inkSoft: Color(0xFFB6B4D0),
    inkFaint: Color(0xFF807EA0),
    hairline: Color.fromRGBO(255, 255, 255, 0.09),
    rowHover: Color.fromRGBO(255, 255, 255, 0.06),
    selTint: Color.fromRGBO(255, 255, 255, 0.13),
    selEdge: Color.fromRGBO(255, 255, 255, 0.22),
    glare: Color.fromRGBO(255, 255, 255, 0.16),
    scrim: Color.fromRGBO(8, 7, 20, 0.52),
    field: Color.fromRGBO(255, 255, 255, 0.06),
    // oklch(0.55 0.13 70 / 0.45) ≈ a muted amber wash.
    markBg: Color.fromRGBO(150, 110, 40, 0.55),
    panelShadow: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.75),
        offset: Offset(0, 50),
        blurRadius: 110,
        spreadRadius: -28,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.60),
        offset: Offset(0, 6),
        blurRadius: 22,
        spreadRadius: -10,
      ),
    ],
  );

  static SearchTokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
