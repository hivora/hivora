import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Turns a fetched logo (raster or SVG) into PNG bytes ready to embed in the
/// PDF. SVGs are rasterized with flutter_svg's renderer (far more capable than
/// the PDF package's built-in SVG engine), so even heavy traced paths embed
/// cleanly. Raster payloads (PNG/JPEG/…) are passed through unchanged. Returns
/// null on any failure so the caller can fall back to the Hinata mark.
Future<Uint8List?> logoToPng({
  required List<int> bytes,
  required bool isSvg,
  double targetHeight = 256,
}) async {
  if (bytes.isEmpty) return null;
  if (!isSvg) return Uint8List.fromList(bytes);
  try {
    final svg = utf8.decode(bytes, allowMalformed: true);
    final info = await vg.loadPicture(SvgStringLoader(svg), null);
    final size = info.size;
    if (size.width <= 0 || size.height <= 0) {
      info.picture.dispose();
      return null;
    }
    final scale = targetHeight / size.height;
    final width = (size.width * scale).ceil().clamp(1, 4000);
    final height = (size.height * scale).ceil().clamp(1, 4000);

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..scale(scale)
      ..drawPicture(info.picture);
    final scaled = recorder.endRecording();
    final image = await scaled.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    info.picture.dispose();
    scaled.dispose();
    image.dispose();
    return data?.buffer.asUint8List();
  } catch (e) {
    debugPrint('logoToPng: failed to rasterize SVG logo: $e');
    return null;
  }
}
