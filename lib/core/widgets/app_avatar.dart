import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../theme/app_colors.dart';

/// Circular avatar with deterministic pastel background and initials fallback.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.imageUrl, this.radius = 18});

  final String name;
  final String? imageUrl;
  final double radius;

  /// Resolves [imageUrl] to an absolute URL. Server-issued avatar URLs are
  /// relative (e.g. `/api/v1/users/{id}/avatar`) so they stay valid regardless
  /// of which host the app reached the server on; here we prefix the app's
  /// configured API base. Absolute (http) URLs pass through unchanged.
  String? _resolved(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    try {
      final base = context.read<ApiClient>().baseUrl;
      if (base.isEmpty) return null;
      return url.startsWith('/') ? '$base$url' : '$base/$url';
    } catch (_) {
      // No ApiClient in scope (e.g. widget tests) — fall back to initials.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final background = AppColors.pastelFor(name.hashCode.abs());
    final resolved = _resolved(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      foregroundImage: resolved != null ? NetworkImage(resolved) : null,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

/// Overlapping avatar stack like the member group in the design header.
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.names, this.max = 3, this.radius = 14});

  final List<String> names;
  final int max;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final visible = names.take(max).toList();
    final overflow = names.length - visible.length;
    return SizedBox(
      height: radius * 2,
      width: visible.isEmpty
          ? 0
          : radius * 2 + (visible.length - 1 + (overflow > 0 ? 1 : 0)) * radius * 1.2,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * radius * 1.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: AppAvatar(name: visible[i], radius: radius),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * radius * 1.2,
              child: CircleAvatar(
                radius: radius,
                backgroundColor: AppColors.navy,
                child: Text(
                  '+$overflow',
                  style: TextStyle(color: Colors.white, fontSize: radius * 0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
