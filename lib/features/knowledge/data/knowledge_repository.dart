import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'knowledge_data.dart';
import 'knowledge_models.dart';

/// In-memory Knowledge store: seed data merged with locally-persisted edits and
/// new articles. Mirrors the reference `view_knowledge.jsx` localStorage layer.
///
/// The bidirectional issue⇄article relationship is *derived* here, never
/// duplicated: article bodies are scanned for `{{issue:KEY-N}}` tokens and
/// inverted into [issueToArticles]. One source of truth, always consistent.
class KnowledgeRepository extends ChangeNotifier {
  KnowledgeRepository();

  static const _storeKey = 'hinata.kb.v1';
  static final _issueTokenRe = RegExp(r'\{\{issue:([A-Z]+-\d+)\}\}');

  final Map<String, KbUser> _users = {for (final u in kSeedUsers) u.id: u};
  final Map<String, KbProject> _projects = {
    for (final p in kSeedProjects) p.id: p
  };
  final Map<String, KbIssue> _issues = {
    for (final i in kSeedIssues) _pubId(i): i
  };
  final Map<String, KbSpace> _spaces = {for (final s in kSeedSpaces) s.id: s};

  /// id → article. Seed first, then overlaid by persisted edits / new docs.
  final Map<String, KbArticle> _articles = {
    for (final a in kSeedArticles) a.id: a
  };

  /// The signed-in user (byline / new-article author). Seed maintainer.
  KbUser get me => _users['u1']!;

  // ── lifecycle ───────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final json = entry.value as Map<String, dynamic>;
        // Persisted edits store the full merged article; overlay seed defaults.
        final seed = _articles[entry.key];
        _articles[entry.key] = seed == null
            ? KbArticle.fromJson(json)
            : _mergeOverride(seed, json);
      }
    } catch (_) {
      // Corrupt store → fall back to the seed cleanly.
    }
    notifyListeners();
  }

  KbArticle _mergeOverride(KbArticle seed, Map<String, dynamic> json) =>
      seed.copyWith(
        spaceId: json['spaceId'] as String?,
        title: json['title'] as String?,
        body: json['body'] as String?,
        updated: json['updated'] as String?,
      );

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Persist anything that differs from / extends the seed.
      final seedIds = {for (final a in kSeedArticles) a.id};
      final out = <String, dynamic>{};
      for (final a in _articles.values) {
        final isNew = !seedIds.contains(a.id);
        final seed = kSeedArticles.cast<KbArticle?>().firstWhere(
              (s) => s?.id == a.id,
              orElse: () => null,
            );
        if (isNew || seed == null || seed.body != a.body || seed.title != a.title || seed.spaceId != a.spaceId) {
          out[a.id] = a.toJson();
        }
      }
      await prefs.setString(_storeKey, jsonEncode(out));
    } catch (_) {/* best-effort */}
  }

  // ── lookups ─────────────────────────────────────────────────────────────

  static String _pubId(KbIssue i) =>
      '${kSeedProjects.firstWhere((p) => p.id == i.projectId).key}-${i.number}';

  String issuePubId(KbIssue i) =>
      '${_projects[i.projectId]?.key ?? '?'}-${i.number}';

  KbUser? userById(String id) => _users[id];
  KbProject? projectById(String id) => _projects[id];
  KbSpace? spaceById(String id) => _spaces[id];
  KbArticle? articleById(String id) => _articles[id];
  KbIssue? issueByPubId(String pubId) => _issues[pubId];

  List<KbUser> get users => kSeedUsers;
  List<KbSpace> get spaces => kSeedSpaces;
  List<KbIssue> get issues => kSeedIssues;
  List<KbArticle> get articles => _articles.values.toList(growable: false);

  List<KbArticle> articlesInSpace(String spaceId) =>
      articles.where((a) => a.spaceId == spaceId).toList();

  int articleCountInSpace(String spaceId) =>
      articles.where((a) => a.spaceId == spaceId).length;

  // ── derived bidirectional links ───────────────────────────────────────────

  /// All issue ids documented by [articleId] (first occurrence order).
  List<KbIssue> linkedIssues(String body) {
    final seen = <String>{};
    final out = <KbIssue>[];
    for (final m in _issueTokenRe.allMatches(body)) {
      final id = m.group(1)!;
      if (seen.add(id)) {
        final issue = _issues[id];
        if (issue != null) out.add(issue);
      }
    }
    return out;
  }

  /// All articles that mention [issuePubId] — the issue's "Documented in".
  /// Derived live by scanning every body; never stored as a join.
  List<KbArticle> articlesForIssue(String issuePubId) {
    final out = <KbArticle>[];
    for (final a in articles) {
      for (final m in _issueTokenRe.allMatches(a.body)) {
        if (m.group(1) == issuePubId) {
          out.add(a);
          break;
        }
      }
    }
    return out;
  }

  /// Related articles referenced via `{{doc:…}}` tokens in [body].
  List<KbArticle> relatedArticles(String body) {
    final re = RegExp(r'\{\{doc:(\w+)\}\}');
    final seen = <String>{};
    final out = <KbArticle>[];
    for (final m in re.allMatches(body)) {
      final id = m.group(1)!;
      if (seen.add(id)) {
        final a = _articles[id];
        if (a != null) out.add(a);
      }
    }
    return out;
  }

  // ── mutations ─────────────────────────────────────────────────────────────

  KbArticle saveEdit(String id, {
    required String title,
    required String body,
    required String spaceId,
  }) {
    final existing = _articles[id]!;
    final next = existing.copyWith(
      title: title,
      body: body,
      spaceId: spaceId,
      updated: 'just now',
    );
    _articles[id] = next;
    _persist();
    notifyListeners();
    return next;
  }

  KbArticle createArticle({
    required String title,
    required String body,
    required String spaceId,
  }) {
    final id = 'k_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final article = KbArticle(
      id: id,
      spaceId: spaceId,
      parentId: null,
      title: title,
      icon: 'file-text',
      authorId: me.id,
      contributorIds: [me.id],
      updated: 'just now',
      created: 'Today',
      reads: 0,
      labels: const [],
      status: 'published',
      body: body,
    );
    _articles[id] = article;
    _persist();
    notifyListeners();
    return article;
  }
}
