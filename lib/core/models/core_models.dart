import 'package:equatable/equatable.dart';

/// Well-known platform feature-flag keys (admin-configurable in Adminbereich →
/// App). All default to OFF when absent, keeping the platform Jira-conform until
/// an admin opts in.
class PlatformFlags {
  PlatformFlags._();

  /// Allow assigning multiple people to an issue (off → single assignee).
  static const multiAssignee = 'multi_assignee';
}

/// Server metadata from GET /api/v1/meta (version gate, branding, flags).
class ServerMeta extends Equatable {
  const ServerMeta({
    required this.serverVersion,
    required this.minAppVersion,
    required this.setupCompleted,
    this.organizationName,
    this.logoUrl,
    this.privacyPolicyUrl = '',
    this.iosStoreUrl = '',
    this.androidStoreUrl = '',
    this.macosStoreUrl = '',
    this.featureFlags = const {},
    this.uploadLimits = const UploadLimits(),
  });

  final String serverVersion;
  final String minAppVersion;
  final bool setupCompleted;
  final String? organizationName;
  final String? logoUrl;
  final String privacyPolicyUrl;

  /// App-store listings the update gate links to, by platform. Configured in
  /// the admin area; blank when not set.
  final String iosStoreUrl;
  final String androidStoreUrl;
  final String macosStoreUrl;
  final Map<String, bool> featureFlags;
  final UploadLimits uploadLimits;

  factory ServerMeta.fromJson(Map<String, dynamic> json) => ServerMeta(
        serverVersion: json['serverVersion'] as String? ?? '0.0.0',
        minAppVersion: json['minAppVersion'] as String? ?? '0.0.0',
        setupCompleted: json['setupCompleted'] as bool? ?? false,
        organizationName: json['organizationName'] as String?,
        logoUrl: (json['logoUrl'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['logoUrl'] as String).trim(),
        privacyPolicyUrl: json['privacyPolicyUrl'] as String? ?? '',
        iosStoreUrl: json['iosStoreUrl'] as String? ?? '',
        androidStoreUrl: json['androidStoreUrl'] as String? ?? '',
        macosStoreUrl: json['macosStoreUrl'] as String? ?? '',
        featureFlags: (json['featureFlags'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v == true)),
        uploadLimits: json['uploadLimits'] is Map<String, dynamic>
            ? UploadLimits.fromJson(json['uploadLimits'] as Map<String, dynamic>)
            : const UploadLimits(),
      );

  bool isFlagEnabled(String flag) => featureFlags[flag] ?? false;

  /// Multiple assignees per issue (default off → single-assignee, Jira-style).
  bool get multiAssignee => isFlagEnabled(PlatformFlags.multiAssignee);

  @override
  List<Object?> get props =>
      [serverVersion, minAppVersion, setupCompleted, organizationName, logoUrl,
        privacyPolicyUrl, iosStoreUrl, androidStoreUrl, macosStoreUrl];
}

/// Attachment upload constraints supplied by the server so the client can
/// validate a selection before sending. Defaults mirror the server defaults.
class UploadLimits extends Equatable {
  const UploadLimits({
    this.maxFileMb = 25,
    this.maxFiles = 10,
    this.maxRequestMb = 100,
    this.allowedContentTypes = const [],
  });

  /// Max size of a single file, in megabytes.
  final int maxFileMb;

  /// Max number of files per upload batch.
  final int maxFiles;

  /// Max aggregate size of one upload batch, in megabytes.
  final int maxRequestMb;

  /// Allowed MIME types; empty means "trust the server to reject".
  final List<String> allowedContentTypes;

  int get maxFileBytes => maxFileMb * 1024 * 1024;
  int get maxRequestBytes => maxRequestMb * 1024 * 1024;

  factory UploadLimits.fromJson(Map<String, dynamic> json) => UploadLimits(
        maxFileMb: json['maxFileMb'] as int? ?? 25,
        maxFiles: json['maxFiles'] as int? ?? 10,
        maxRequestMb: json['maxRequestMb'] as int? ?? 100,
        allowedContentTypes:
            ((json['allowedContentTypes'] as List<dynamic>?) ?? const [])
                .map((e) => e.toString())
                .toList(growable: false),
      );

  @override
  List<Object?> get props =>
      [maxFileMb, maxFiles, maxRequestMb, allowedContentTypes];
}

class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.roles,
    this.avatarUrl,
    this.title,
    this.locale = 'en',
  });

  final String id;
  final String email;
  final String username;
  final String displayName;
  final Set<String> roles;
  final String? avatarUrl;
  final String? title;
  final String locale;

  bool get isAdmin => roles.contains('ADMIN');

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String? ?? json['username'] as String,
        roles: ((json['roles'] as List<dynamic>?) ?? []).cast<String>().toSet(),
        avatarUrl: json['avatarUrl'] as String?,
        title: json['title'] as String?,
        locale: json['locale'] as String? ?? 'en',
      );

  @override
  List<Object?> get props => [id, email, username, displayName, roles, title];
}

/// Outcome of a password login: either a token pair (+ user), or a 2FA
/// challenge carrying the short-lived [mfaToken] the caller completes with a
/// TOTP / recovery code before a real session is issued.
class LoginResult {
  const LoginResult._({
    required this.mfaRequired,
    this.access,
    this.refresh,
    this.user,
    this.mfaToken,
  });

  factory LoginResult.tokens({
    required String access,
    required String refresh,
    required AuthUser user,
  }) =>
      LoginResult._(mfaRequired: false, access: access, refresh: refresh, user: user);

  factory LoginResult.twoFactor(String mfaToken) =>
      LoginResult._(mfaRequired: true, mfaToken: mfaToken);

  final bool mfaRequired;
  final String? access;
  final String? refresh;
  final AuthUser? user;
  final String? mfaToken;
}

class DirectoryUser extends Equatable {
  const DirectoryUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.title,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? title;

  factory DirectoryUser.fromJson(Map<String, dynamic> json) => DirectoryUser(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        title: json['title'] as String?,
      );

  @override
  List<Object?> get props => [id, username, displayName];
}

class SsoProvider extends Equatable {
  const SsoProvider({required this.id, required this.displayName, required this.loginUrl});

  final String id;
  final String displayName;
  final String loginUrl;

  factory SsoProvider.fromJson(Map<String, dynamic> json) => SsoProvider(
        id: json['id'] as String,
        displayName: json['displayName'] as String? ?? json['id'] as String,
        loginUrl: json['loginUrl'] as String,
      );

  @override
  List<Object?> get props => [id, displayName, loginUrl];
}

/// Compares dotted semantic versions; returns true when [current] < [minimum].
bool isVersionBelow(String current, String minimum) {
  List<int> parse(String v) =>
      v.split('.').map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9].*'), '')) ?? 0).toList();
  final a = parse(current);
  final b = parse(minimum);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}
