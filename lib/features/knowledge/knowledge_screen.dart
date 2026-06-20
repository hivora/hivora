import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hive_loader.dart';
import '../../core/widgets/hive_widgets.dart';
import 'data/knowledge_models.dart';
import 'data/knowledge_repository.dart';
import 'knowledge_editor.dart';
import 'knowledge_home.dart';
import 'knowledge_issue_sheet.dart';
import 'knowledge_reader.dart';
import 'knowledge_scope.dart';
import 'knowledge_tokens.dart';
import 'knowledge_tree.dart';

/// Confluence-style Knowledge Base shell: spaces home, nested article tree,
/// reader with TOC/aside/linked-issues, and a full markdown editor with
/// `@`-smart-links. Self-contained (seed data + local persistence); a 1:1 port
/// of the design reference `view_knowledge.jsx`. Internal navigation between
/// home/space/article/edit/new is managed here (not via the router).
class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key, this.initialArticleId});

  /// Deep link from `/knowledge/:id` — open straight into this article.
  final String? initialArticleId;

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

enum _Mode { home, article, edit, newDoc }

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  final KnowledgeRepository _repo = KnowledgeRepository();
  bool _ready = false;

  _Mode _mode = _Mode.home;
  String? _selectedId;
  late String _spaceId = _repo.spaces.first.id;
  final _scrollKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _repo.init().then((_) {
      if (!mounted) return;
      final initial = widget.initialArticleId;
      if (initial != null && _repo.articleById(initial) != null) {
        final a = _repo.articleById(initial)!;
        _selectedId = initial;
        _spaceId = a.spaceId;
        _mode = _Mode.article;
      }
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  KbArticle? get _current =>
      _selectedId == null ? null : _repo.articleById(_selectedId!);

  // ── navigation ──
  void _openArticle(String id) {
    final a = _repo.articleById(id);
    if (a == null) return;
    setState(() {
      _selectedId = id;
      _spaceId = a.spaceId;
      _mode = _Mode.article;
    });
  }

  void _openSpace(String id) {
    final first = _repo.articlesInSpace(id).where((a) => a.parentId == null);
    setState(() {
      _spaceId = id;
      if (first.isNotEmpty) {
        _selectedId = first.first.id;
        _mode = _Mode.article;
      }
    });
  }

  void _openIssue(KbIssue issue) {
    showKnowledgeIssueSheet(context,
        repo: _repo, issue: issue, onOpenArticle: _openArticle);
  }

  void _home() => setState(() {
        _mode = _Mode.home;
        _selectedId = null;
      });

  void _save(EditorResult r) {
    final title = r.title.trim().isEmpty ? 'Untitled' : r.title.trim();
    if (_mode == _Mode.newDoc) {
      final a = _repo.createArticle(
          title: title, body: r.body, spaceId: r.spaceId);
      setState(() {
        _selectedId = a.id;
        _spaceId = a.spaceId;
        _mode = _Mode.article;
      });
      _toast('Article published');
    } else if (_current != null) {
      _repo.saveEdit(_current!.id,
          title: title, body: r.body, spaceId: r.spaceId);
      setState(() => _mode = _Mode.article);
      _toast('Changes saved');
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  void _openTreeDrawer() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        margin: EdgeInsets.only(top: MediaQuery.of(sheetCtx).padding.top + 40),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: KnowledgeTree(
              repo: _repo,
              spaceId: _spaceId,
              selectedId: _selectedId,
              onSelect: (id) {
                Navigator.of(sheetCtx).pop();
                _openArticle(id);
              },
              onSpaceChange: (id) {
                Navigator.of(sheetCtx).pop();
                _openSpace(id);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: HiveLoader()));
    }
    return KnowledgeScope(
      repo: _repo,
      openArticle: _openArticle,
      openIssue: _openIssue,
      openUser: (_) {},
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final bp = w < KbTokens.bpMid
              ? _Bp.narrow
              : w < KbTokens.bpWide
                  ? _Bp.mid
                  : _Bp.wide;
          if (_mode == _Mode.edit || _mode == _Mode.newDoc) {
            return _editorView(constraints.maxHeight);
          }
          return _mainView(bp);
        },
      ),
    );
  }

  Widget _head() {
    return PageHead(
      title: 'Knowledge base',
      subtitle:
          '${_repo.articles.length} articles · ${_repo.spaces.length} spaces',
      actions: [
        if (_mode != _Mode.home)
          GhostButton(
            label: 'All spaces',
            icon: lucideIcon('layout-grid'),
            onPressed: _home,
          ),
        PrimaryButton(
          label: 'New article',
          icon: lucideIcon('plus'),
          onPressed: () => setState(() => _mode = _Mode.newDoc),
        ),
      ],
    );
  }

  Widget _mainView(_Bp bp) {
    final showTree = _mode == _Mode.article && bp != _Bp.narrow;
    return SingleChildScrollView(
      key: _scrollKey,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        context.pageGutter,
        24 + context.topGutter,
        context.pageGutter,
        context.pageGutter + context.bottomGutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(),
          const SizedBox(height: 20),
          if (_mode == _Mode.home)
            KnowledgeHome(
              repo: _repo,
              onOpenArticle: _openArticle,
              onOpenSpace: _openSpace,
            )
          else if (_current != null)
            _articleLayout(bp, showTree),
        ],
      ),
    );
  }

  Widget _articleLayout(_Bp bp, bool showTree) {
    final reader = KnowledgeReader(
      article: _current!,
      asideMode: switch (bp) {
        _Bp.wide => AsideMode.side,
        _Bp.mid => AsideMode.below,
        _Bp.narrow => AsideMode.none,
      },
      onEdit: () => setState(() => _mode = _Mode.edit),
    );

    if (!showTree) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // narrow bar with tree drawer trigger
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(KbTokens.radiusControl),
                child: InkWell(
                  borderRadius: BorderRadius.circular(KbTokens.radiusControl),
                  onTap: _openTreeDrawer,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(KbTokens.radiusControl),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(lucideIcon('panel-left'),
                            size: 16, color: AppColors.inkSoft),
                        const SizedBox(width: 8),
                        Text(_repo.spaceById(_spaceId)?.name ?? '',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          reader,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: KbTokens.treeWidth,
          child: KnowledgeTree(
            repo: _repo,
            spaceId: _spaceId,
            selectedId: _selectedId,
            onSelect: _openArticle,
            onSpaceChange: _openSpace,
          ),
        ),
        const SizedBox(width: 28),
        Expanded(child: reader),
      ],
    );
  }

  Widget _editorView(double maxHeight) {
    final isNew = _mode == _Mode.newDoc;
    final current = _current;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pageGutter,
        16 + context.topGutter,
        context.pageGutter,
        context.pageGutter + context.bottomGutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(KbTokens.radiusControl),
                child: InkWell(
                  borderRadius: BorderRadius.circular(KbTokens.radiusControl),
                  onTap: () =>
                      setState(() => _mode = isNew ? _Mode.home : _Mode.article),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(KbTokens.radiusControl),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Icon(lucideIcon('arrow-left'),
                        size: 18, color: AppColors.inkSoft),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(isNew ? 'New article' : 'Editing',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontBrand,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: KnowledgeEditor(
              isNew: isNew,
              initialTitle: isNew ? '' : current?.title ?? '',
              initialBody: isNew ? '' : current?.body ?? '',
              spaceId: _spaceId,
              onSave: _save,
              onCancel: () =>
                  setState(() => _mode = isNew ? _Mode.home : _Mode.article),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Bp { narrow, mid, wide }
