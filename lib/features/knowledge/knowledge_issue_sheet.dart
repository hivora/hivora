import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_avatar.dart';
import 'data/knowledge_models.dart';
import 'data/knowledge_repository.dart';
import 'knowledge_scope.dart';
import 'knowledge_tokens.dart';
import 'markdown/markdown_renderer.dart';
import 'markdown/mention_field.dart';

/// Opens the issue slide-over for [issue]. Full-bleed on phone, a centred panel
/// on wider screens. Shows the issue summary, its derived *Documented in*
/// articles, and a comment box that accepts `@`-smart-links.
Future<void> showKnowledgeIssueSheet(
  BuildContext context, {
  required KnowledgeRepository repo,
  required KbIssue issue,
  required ValueChanged<String> onOpenArticle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navyDeep.withValues(alpha: 0.42),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final phone = media.size.width < KbTokens.bpPhone;
      final maxW = phone ? media.size.width : 620.0;
      return Padding(
        padding: EdgeInsets.only(top: phone ? media.padding.top + 8 : 40),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: KnowledgeScope(
              repo: repo,
              openArticle: (id) {
                Navigator.of(sheetContext).pop();
                onOpenArticle(id);
              },
              openIssue: (it) => showKnowledgeIssueSheet(sheetContext,
                  repo: repo, issue: it, onOpenArticle: onOpenArticle),
              openUser: (_) {},
              child: _IssueSheet(issue: issue),
            ),
          ),
        ),
      );
    },
  );
}

class _IssueSheet extends StatefulWidget {
  const _IssueSheet({required this.issue});
  final KbIssue issue;

  @override
  State<_IssueSheet> createState() => _IssueSheetState();
}

class _Comment {
  _Comment(this.authorId, this.text);
  final String authorId;
  final String text;
}

class _IssueSheetState extends State<_IssueSheet> {
  final _comment = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final List<_Comment> _comments = [];

  @override
  void dispose() {
    _comment.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    final repo = KnowledgeScope.of(context).repo;
    setState(() {
      _comments.add(_Comment(repo.me.id, text));
      _comment.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = KnowledgeScope.of(context).repo;
    final issue = widget.issue;
    final tm = typeMeta(issue.type);
    final sm = stateMeta(issue.state);
    final pm = priorityMeta(issue.priority);
    final color = KbTokens.issueChipColor(tm.hue);
    final assignee =
        issue.assigneeId == null ? null : repo.userById(issue.assigneeId!);
    final documentedIn = repo.articlesForIssue(repo.issuePubId(issue));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(lucideIcon(tm.icon), size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Text(repo.issuePubId(issue),
                    style: TextStyle(
                        fontFamily: AppTheme.fontMono,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(lucideIcon('x'), size: 20),
                  color: AppColors.inkSoft,
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.title,
                      style: const TextStyle(
                          fontFamily: AppTheme.fontBrand,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _stateChip(sm),
                      _metaChip(
                          Icon(lucideIcon(pm.icon),
                              size: 14, color: AppColors.inkSoft),
                          pm.label),
                      if (assignee != null)
                        _metaChip(AppAvatar(name: assignee.name, radius: 9),
                            assignee.firstName),
                      for (final t in issue.tags) _tag(t),
                    ],
                  ),
                  if (documentedIn.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _sectionHeader(
                        lucideIcon('link-2'), 'Documented in', documentedIn.length),
                    const SizedBox(height: 10),
                    for (final a in documentedIn)
                      _DocRow(repo: repo, article: a),
                  ],
                  const SizedBox(height: 24),
                  _sectionHeader(lucideIcon('quote'), 'Comments', _comments.length),
                  const SizedBox(height: 10),
                  for (final c in _comments) _commentTile(repo, c),
                  const SizedBox(height: 10),
                  _commentBox(repo),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentBox(KnowledgeRepository repo) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(KbTokens.radiusControl),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, maxHeight: 160),
            child: MentionField(
              controller: _comment,
              focusNode: _commentFocus,
              commentMode: true,
              minLines: 1,
              maxLines: 6,
              hintText: 'Write a comment… type @ to link',
              onSubmit: _submitComment,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline2)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Row(
              children: [
                Text('⌘↵ to send',
                    style: TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                const Spacer(),
                FilledButton(
                  onPressed: _submitComment,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Comment'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentTile(KnowledgeRepository repo, _Comment c) {
    final author = repo.userById(c.authorId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(name: author?.name ?? '?', radius: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(author?.name ?? '?',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ...KbMarkdownParser(fontSize: 13.5).parse(c.text).nodes,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, int count) => Row(
        children: [
          Icon(icon, size: 16, color: KbTokens.accent),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text('$count',
                style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkFaint)),
          ),
        ],
      );

  Widget _stateChip(StateMeta sm) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: KbTokens.stateDot(sm.hue).withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(KbTokens.radiusChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: KbTokens.stateDot(sm.hue), shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(sm.name,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: KbTokens.stateInk(sm.hue))),
          ],
        ),
      );

  Widget _metaChip(Widget leading, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(KbTokens.radiusChip),
          border: Border.all(color: AppColors.hairline2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 6),
            Text(text,
                style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
          ],
        ),
      );

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(KbTokens.radiusChip),
          border: Border.all(color: AppColors.hairline2),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
      );
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.repo, required this.article});
  final KnowledgeRepository repo;
  final KbArticle article;

  @override
  Widget build(BuildContext context) {
    final sp = repo.spaceById(article.spaceId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(KbTokens.radiusControl),
        child: InkWell(
          onTap: () => KnowledgeScope.of(context).openArticle(article.id),
          borderRadius: BorderRadius.circular(KbTokens.radiusControl),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KbTokens.radiusControl),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                Icon(lucideIcon(article.icon), size: 17, color: KbTokens.accent),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(article.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(sp?.name ?? '',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
                Icon(lucideIcon('chevron-right'),
                    size: 16, color: AppColors.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
