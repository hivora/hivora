import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'data/knowledge_models.dart';
import 'data/knowledge_repository.dart';
import 'knowledge_tokens.dart';

/// Space switcher + nested article tree. Rendered in the reader's left sidebar
/// (≥ 720 px) and inside the phone drawer.
class KnowledgeTree extends StatelessWidget {
  const KnowledgeTree({
    super.key,
    required this.repo,
    required this.spaceId,
    required this.selectedId,
    required this.onSelect,
    required this.onSpaceChange,
  });

  final KnowledgeRepository repo;
  final String spaceId;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onSpaceChange;

  @override
  Widget build(BuildContext context) {
    final inSpace = repo.articlesInSpace(spaceId);
    final roots = inSpace.where((a) => a.parentId == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(KbTokens.radiusControl),
              border: Border.all(color: AppColors.hairline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: spaceId,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(KbTokens.radiusControl),
                style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink),
                items: [
                  for (final s in repo.spaces)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) {
                  if (v != null) onSpaceChange(v);
                },
              ),
            ),
          ),
        ),
        for (final root in roots)
          _TreeBranch(
            repo: repo,
            article: root,
            inSpace: inSpace,
            depth: 0,
            selectedId: selectedId,
            onSelect: onSelect,
          ),
      ],
    );
  }
}

class _TreeBranch extends StatefulWidget {
  const _TreeBranch({
    required this.repo,
    required this.article,
    required this.inSpace,
    required this.depth,
    required this.selectedId,
    required this.onSelect,
  });

  final KnowledgeRepository repo;
  final KbArticle article;
  final List<KbArticle> inSpace;
  final int depth;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<_TreeBranch> createState() => _TreeBranchState();
}

class _TreeBranchState extends State<_TreeBranch> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final kids =
        widget.inSpace.where((a) => a.parentId == widget.article.id).toList();
    final selected = widget.selectedId == widget.article.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: selected ? AppColors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => widget.onSelect(widget.article.id),
            child: Padding(
              padding: EdgeInsets.fromLTRB(8 + widget.depth * 14, 7, 8, 7),
              child: Row(
                children: [
                  if (kids.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _open = !_open),
                      child: Icon(
                          lucideIcon(_open ? 'chevron-down' : 'chevron-right'),
                          size: 15,
                          color: AppColors.inkFaint),
                    )
                  else
                    const SizedBox(width: 15),
                  const SizedBox(width: 6),
                  Icon(lucideIcon(widget.article.icon),
                      size: 15,
                      color: selected ? KbTokens.accent : AppColors.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.article.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? AppColors.ink : AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open)
          for (final c in kids)
            _TreeBranch(
              repo: widget.repo,
              article: c,
              inSpace: widget.inSpace,
              depth: widget.depth + 1,
              selectedId: widget.selectedId,
              onSelect: widget.onSelect,
            ),
      ],
    );
  }
}
