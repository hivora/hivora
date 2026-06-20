import 'package:flutter/widgets.dart';

import 'data/knowledge_models.dart';
import 'data/knowledge_repository.dart';

/// Ambient access to the [KnowledgeRepository] plus the navigation callbacks a
/// smart-link chip needs to act on a click (open an issue slide-over / jump to
/// an article / peek a person). Provided once by the shell so the markdown
/// renderer and chips resolve tokens against live data without prop-drilling.
class KnowledgeScope extends InheritedWidget {
  const KnowledgeScope({
    super.key,
    required this.repo,
    required this.openArticle,
    required this.openIssue,
    required this.openUser,
    required super.child,
  });

  final KnowledgeRepository repo;
  final void Function(String articleId) openArticle;
  final void Function(KbIssue issue) openIssue;
  final void Function(KbUser user) openUser;

  static KnowledgeScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<KnowledgeScope>();
    assert(scope != null, 'No KnowledgeScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(KnowledgeScope oldWidget) =>
      repo != oldWidget.repo;
}
