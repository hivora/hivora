import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../data/knowledge_models.dart' show lucideIcon;
import '../knowledge_tokens.dart';

/// Prefix of the transient placeholder URL used by the inline image-upload flow
/// (see `markdown_image_upload.dart`) while the upload is in flight.
const String kUploadingImageScheme = 'hinata-uploading:';

/// Process-wide cache of decoded image bytes, keyed by the fetch path/URL.
/// `null` marks a URL that failed so we don't refetch it on every rebuild.
final Map<String, Uint8List?> _imageBytesCache = {};
final Map<String, Future<void>> _imageInFlight = {};

/// Renders a Markdown image (`![alt](url)`).
///
/// Plain [Image.network] does **not** work for these on Flutter web: CanvasKit
/// taints on a cross-origin `<img>` without CORS headers and the image silently
/// disappears (the old renderer swallowed the error into an empty box). Instead
/// the bytes are fetched through XHR and drawn with [Image.memory] — the same
/// approach that makes avatars show on web:
///
///  • our own uploaded media / API-relative URLs → authenticated [ApiClient]
///    fetch (carries the bearer token, same-origin, no CORS problem);
///  • external absolute URLs on **web** → routed through the server image proxy
///    (`/api/v1/media/proxy`) so the cross-origin fetch happens server-side;
///  • external absolute URLs on **native** → plain [Image.network] (no CORS).
class MarkdownImage extends StatefulWidget {
  const MarkdownImage({super.key, required this.url, this.alt});

  final String url;
  final String? alt;

  @override
  State<MarkdownImage> createState() => _MarkdownImageState();
}

class _MarkdownImageState extends State<MarkdownImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  /// True when the byte pipeline (our media / web proxy) is used; false when we
  /// fall back to a native [Image.network].
  bool _viaBytes = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant MarkdownImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _resolve();
    }
  }

  /// The API-relative path to fetch [widget.url] through, or null when it is an
  /// external URL that should not go through the authenticated bytes endpoint.
  String? _fetchPath(ApiClient api) {
    final url = widget.url;
    if (url.startsWith('/')) return url; // already API-relative
    final base = api.baseUrl;
    if (base.isNotEmpty && url.startsWith(base)) {
      return url.substring(base.length);
    }
    return null;
  }

  Future<void> _resolve() async {
    final url = widget.url;
    // Still uploading — show a spinner, resolved once the placeholder is
    // replaced with the real URL (which rebuilds this widget with a new key).
    if (url.startsWith(kUploadingImageScheme)) {
      setState(() {
        _loading = true;
        _failed = false;
        _bytes = null;
      });
      return;
    }

    ApiClient? api;
    try {
      api = context.read<ApiClient>();
    } catch (_) {
      api = null;
    }

    String? path = api == null ? null : _fetchPath(api);
    if (path == null && api != null && kIsWeb && url.startsWith('http')) {
      // External image on web: proxy it server-side to dodge CORS.
      path = '/api/v1/media/proxy?url=${Uri.encodeQueryComponent(url)}';
    }

    if (path == null || api == null) {
      // Native external URL (no CORS) — or no ApiClient in scope. Let Flutter
      // load it directly and report failures through the frameBuilder.
      setState(() {
        _viaBytes = false;
        _loading = false;
        _failed = false;
      });
      return;
    }

    _viaBytes = true;
    if (_imageBytesCache.containsKey(path)) {
      _apply(_imageBytesCache[path]);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    final pending = _imageInFlight[path] ??= _fetch(api, path);
    await pending;
    if (mounted) _apply(_imageBytesCache[path]);
  }

  Future<void> _fetch(ApiClient api, String path) async {
    try {
      final result = await api.getBytes(path);
      _imageBytesCache[path] = result == null
          ? null
          : Uint8List.fromList(result.bytes);
    } catch (_) {
      _imageBytesCache[path] = null;
    } finally {
      _imageInFlight.remove(path);
    }
  }

  void _apply(Uint8List? bytes) {
    setState(() {
      _bytes = bytes;
      _loading = false;
      _failed = bytes == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
        child: _content(),
      ),
    );
  }

  Widget _content() {
    if (_loading) return _frame(child: _spinner());
    if (_failed) return _brokenChip();

    if (!_viaBytes) {
      // Native external image: draw directly, surfacing load errors as the chip.
      return ClipRRect(
        borderRadius: BorderRadius.circular(KbTokens.radiusCard),
        child: Image.network(
          widget.url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _brokenChip(),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _frame(child: _spinner()),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(KbTokens.radiusCard),
      child: Image.memory(
        _bytes!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _brokenChip(),
      ),
    );
  }

  Widget _frame({required Widget child}) => Container(
    constraints: const BoxConstraints(minWidth: 120, minHeight: 90),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(KbTokens.radiusCard),
      border: Border.all(color: AppColors.hairline),
    ),
    alignment: Alignment.center,
    child: child,
  );

  Widget _spinner() => const SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  Widget _brokenChip() => _frame(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(lucideIcon('image-off'), size: 20, color: AppColors.inkFaint),
          if ((widget.alt ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.alt!.trim(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.inkFaint),
            ),
          ],
        ],
      ),
    ),
  );
}
