import 'package:flutter/material.dart';

/// Faint honeycomb texture used behind the nav rail (and reusable elsewhere).
///
/// Mirrors the v2 design's `.rail::after` layer: a pointy-top hexagon tile
/// (SVG viewBox 56×64, path `M28 1 54 16v32L28 63 2 48V16z`) repeated on a
/// 42×48 grid, drawn as a hairline stroke at very low opacity, and faded in
/// from the top via a vertical mask so it only reads near the base.
///
/// Sizes itself to the incoming constraints, so place it in a `Positioned`
/// (e.g. a bottom band) or `Positioned.fill` behind your content.
class HoneycombBackground extends StatelessWidget {
  const HoneycombBackground({
    super.key,
    this.color = Colors.white,
    this.opacity = 0.05,
    this.tileSize = const Size(42, 48),
    this.strokeWidth = 0.9,
    this.fadeStart = 0.0,
    this.fadeEnd = 0.7,
  });

  /// Stroke colour of the hex outlines (alpha is applied via [opacity]).
  final Color color;

  /// Stroke opacity of the hex outlines.
  final double opacity;

  /// One repeat cell. The hexagon is scaled to fill it, matching the
  /// design's `background-size`.
  final Size tileSize;

  /// Hairline stroke width in logical pixels.
  final double strokeWidth;

  /// Vertical mask: fully transparent at [fadeStart], fully opaque from
  /// [fadeEnd] downward (fractions of the painted height).
  final double fadeStart;
  final double fadeEnd;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HoneycombPainter(
          color: color.withValues(alpha: opacity),
          tileSize: tileSize,
          strokeWidth: strokeWidth,
          fadeStart: fadeStart,
          fadeEnd: fadeEnd,
        ),
      ),
    );
  }
}

class _HoneycombPainter extends CustomPainter {
  _HoneycombPainter({
    required this.color,
    required this.tileSize,
    required this.strokeWidth,
    required this.fadeStart,
    required this.fadeEnd,
  });

  final Color color;
  final Size tileSize;
  final double strokeWidth;
  final double fadeStart;
  final double fadeEnd;

  // Hexagon vertices as fractions of the tile, from the design path
  // `M28 1 54 16v32L28 63 2 48V16z` over a 56×64 viewBox.
  static const _vertices = <Offset>[
    Offset(28 / 56, 1 / 64), // top point
    Offset(54 / 56, 16 / 64), // upper right
    Offset(54 / 56, 48 / 64), // lower right
    Offset(28 / 56, 63 / 64), // bottom point
    Offset(2 / 56, 48 / 64), // lower left
    Offset(2 / 56, 16 / 64), // upper left
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Isolate the texture so the vertical fade mask only affects it.
    canvas.saveLayer(Offset.zero & size, Paint());

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final tile = _tilePath();
    final tw = tileSize.width;
    final th = tileSize.height;

    // Start one cell early so partial hexes cover the top/left edges.
    for (double y = -th; y < size.height + th; y += th) {
      for (double x = -tw; x < size.width + tw; x += tw) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPath(tile, paint);
        canvas.restore();
      }
    }

    // Fade the texture in from the top (transparent → opaque) like the
    // design's `mask-image: linear-gradient(180deg, transparent, #000 70%)`.
    final mask = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.transparent, Colors.white],
        stops: [fadeStart, fadeEnd],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, mask);

    canvas.restore();
  }

  Path _tilePath() {
    final tw = tileSize.width;
    final th = tileSize.height;
    final path = Path();
    for (var i = 0; i < _vertices.length; i++) {
      final p = Offset(_vertices[i].dx * tw, _vertices[i].dy * th);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_HoneycombPainter old) =>
      old.color != color ||
      old.tileSize != tileSize ||
      old.strokeWidth != strokeWidth ||
      old.fadeStart != fadeStart ||
      old.fadeEnd != fadeEnd;
}
