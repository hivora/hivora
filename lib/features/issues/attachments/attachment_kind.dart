import 'package:flutter/material.dart';

/// Visual + semantic metadata for an attachment "kind", mirroring `KIND_META`
/// in the web design (`view_attachments.jsx`). Colours are sRGB approximations
/// of the reference oklch values.
class AttachmentKindMeta {
  const AttachmentKindMeta(this.icon, this.color);
  final IconData icon;
  final Color color;
}

const Map<String, AttachmentKindMeta> _kindMeta = {
  'image': AttachmentKindMeta(Icons.image_outlined, Color(0xFF4F74B8)),
  'pdf': AttachmentKindMeta(Icons.picture_as_pdf_outlined, Color(0xFFC1503C)),
  'doc': AttachmentKindMeta(Icons.description_outlined, Color(0xFF5566A8)),
  'sheet': AttachmentKindMeta(Icons.table_chart_outlined, Color(0xFF3E9168)),
  'zip': AttachmentKindMeta(Icons.folder_zip_outlined, Color(0xFFB07F38)),
  'figma': AttachmentKindMeta(Icons.brush_outlined, Color(0xFF9A57BE)),
  'video': AttachmentKindMeta(Icons.movie_outlined, Color(0xFFBE5479)),
  'file': AttachmentKindMeta(Icons.insert_drive_file_outlined, Color(0xFF7B7E88)),
};

AttachmentKindMeta kindMeta(String kind) => _kindMeta[kind] ?? _kindMeta['file']!;

bool kindIsImage(String kind) => kind == 'image';

/// Mirrors `kindFromName()`: switch on MIME first, then file extension.
String kindFromName(String name, [String? mime]) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  if ((mime != null && mime.startsWith('image/')) ||
      const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'heic'].contains(ext)) {
    return 'image';
  }
  if ((mime != null && mime.startsWith('video/')) ||
      const ['mp4', 'mov', 'webm', 'avi'].contains(ext)) {
    return 'video';
  }
  if (ext == 'pdf') return 'pdf';
  if (const ['doc', 'docx', 'rtf', 'txt', 'md', 'pages'].contains(ext)) {
    return 'doc';
  }
  if (const ['xls', 'xlsx', 'csv', 'numbers'].contains(ext)) return 'sheet';
  if (const ['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) return 'zip';
  if (const ['fig', 'sketch', 'xd'].contains(ext)) return 'figma';
  return 'file';
}

/// The short tag shown on the thumbnail: the extension for images, else the kind.
String kindTag(String kind, String name) {
  if (kind == 'image') {
    return name.contains('.') ? name.split('.').last : 'img';
  }
  return kind;
}

/// Human-readable size, mirroring `fmtSize()` (B / KB / MB).
String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) {
    return '${(b / 1024).toStringAsFixed(b < 10240 ? 1 : 0)} KB';
  }
  return '${(b / 1048576).toStringAsFixed(b < 10485760 ? 1 : 0)} MB';
}

/// Compact relative age, e.g. "now", "5m", "3h", "2d", "3w" — matches the
/// design's "Xd ago" sublabel without depending on a locale package.
String relativeAge(DateTime when) {
  final d = DateTime.now().difference(when);
  if (d.inSeconds < 45) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 30) return '${(d.inDays / 7).floor()}w';
  if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo';
  return '${(d.inDays / 365).floor()}y';
}

/// Extensions that are clearly executable / scriptable. Rejected client-side
/// with a friendly message; the server whitelist of MIME types is the real
/// gate (these never appear in it), this just avoids a wasted round-trip.
const Set<String> kBlockedExtensions = {
  'exe', 'msi', 'bat', 'cmd', 'com', 'scr', 'pif', 'cpl', 'dll', 'sys',
  'sh', 'bash', 'zsh', 'ksh', 'run', 'bin', 'app', 'command',
  'js', 'jse', 'vbs', 'vbe', 'wsf', 'wsh', 'ps1', 'psm1', 'hta',
  'jar', 'apk', 'deb', 'rpm', 'dmg', 'pkg',
  'reg', 'lnk', 'gadget', 'inf', 'ade', 'adp', 'mst',
};

bool isBlockedFileName(String name) {
  if (!name.contains('.')) return false;
  return kBlockedExtensions.contains(name.split('.').last.toLowerCase());
}
