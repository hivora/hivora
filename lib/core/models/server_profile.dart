import 'package:equatable/equatable.dart';

/// A backend the app knows about. The user can save several and switch between
/// them; each keeps its own auth tokens (scoped in [AppStorage] by [url]), so
/// signing into one server never leaks credentials to another.
class ServerProfile extends Equatable {
  const ServerProfile({required this.url, this.label});

  /// Normalized base URL (no trailing slash), e.g. `https://api.acme.com`.
  /// Also the stable identity of the profile.
  final String url;

  /// Friendly name (the server's organization name), when known. Falls back to
  /// the host for display.
  final String? label;

  /// The bare host (`acme.com`) used as a compact secondary label.
  String get host => Uri.tryParse(url)?.host ?? url;

  /// What to show the user: the organization name when we have one, else host.
  String get displayName =>
      (label != null && label!.trim().isNotEmpty) ? label!.trim() : host;

  Map<String, dynamic> toJson() => {
        'url': url,
        if (label != null) 'label': label,
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
        url: json['url'] as String,
        label: json['label'] as String?,
      );

  @override
  List<Object?> get props => [url, label];
}
