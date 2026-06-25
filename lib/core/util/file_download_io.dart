import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Native: write the bytes to the platform downloads dir (falling back to the
/// app documents dir) and return the saved path.
Future<String?> downloadBytes(
    String filename, Uint8List bytes, String mimeType) async {
  Directory dir;
  try {
    dir = (await getDownloadsDirectory()) ??
        await getApplicationDocumentsDirectory();
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }
  final safe = filename.replaceAll(RegExp(r'[\\/\x00]'), '_').trim();
  final file = File('${dir.path}/${safe.isEmpty ? 'download' : safe}');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
