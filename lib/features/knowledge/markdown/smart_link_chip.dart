import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_avatar.dart';
import '../data/knowledge_models.dart';
import '../data/knowledge_repository.dart';
import '../knowledge_scope.dart';
import '../knowledge_tokens.dart';

/// Inline, clickable, hoverable smart-link chip rendered from a `{{…}}` token.
///
/// - `issue`  → type glyph + public id, tinted by issue type; opens the issue
///              slide-over. Missing target → a danger "broken link" chip.
/// - `doc`    → article icon + title, honey accent; opens the article.
/// - `user`   → avatar + first name on a soft accent fill.
///
/// On hover (desktop) / long-press (touch) a floating [_SmartPreview] card is
/// shown, anchored to the chip and flipped above when it would overflow the
/// viewport bottom (`opacity 0→1, translateY −4→0, 160 ms`, reduced-motion safe).
class SmartLinkChip extends StatefulWidget {
  const SmartLinkChip({super.key, required this.kind, required this.id});

  final String kind; // issue | doc | user
  final String id;

  @override
  State<SmartLinkChip> createState() => _SmartLinkChipState();
}

class _SmartLinkChipState extends State<SmartLinkChip> {
  OverlayEntry? _entry;
  bool _hovered = false;

  @override
  void dispose() {
    _removePreview();
    super.dispose();
  }

  KnowledgeRepository get _repo => KnowledgeScope.of(context).repo;

  void _showPreview() {
    if (_entry != null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final chipRect = topLeft & box.size;
    final viewport = overlayBox.size;

    final card = _buildPreviewCard();
    if (card == null) return;

    const w = 320.0;
    var left = chipRect.left;
    if (left + w > viewport.width - 12) left = viewport.width - w - 12;
    if (left < 12) left = 12;
    final flipUp = chipRect.bottom + 160 > viewport.height;

    _entry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: flipUp ? null : chipRect.bottom + 6,
        bottom: flipUp ? viewport.height - chipRect.top + 6 : null,
        width: w,
        child: _SmartPreview(child: card),
      ),
    );
    overlay.insert(_entry!);
  }

  void _removePreview() {
    _entry?.remove();
    _entry = null;
  }

  void _open() {
    final scope = KnowledgeScope.of(context);
    if (widget.kind == 'issue') {
      final issue = _repo.issueByPubId(widget.id);
      if (issue != null) scope.openIssue(issue);
    } else if (widget.kind == 'doc') {
      if (_repo.articleById(widget.id) != null) scope.openArticle(widget.id);
    } else if (widget.kind == 'user') {
      final user = _repo.userById(widget.id);
      if (user != null) scope.openUser(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = _buildChip();
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _showPreview();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _removePreview();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        onLongPress: _showPreview,
        onLongPressUp: _removePreview,
        child: chip,
      ),
    );
  }

  // ── chip face ──
  Widget _buildChip() {
    switch (widget.kind) {
      case 'user':
        final u = _repo.userById(widget.id);
        if (u == null) return _broken('@unknown');
        return _chipShell(
          background: AppColors.accentSoft,
          border: AppColors.accentLine,
          padStart: 3,
          children: [
            AppAvatar(name: u.name, radius: 8),
            const SizedBox(width: 5),
            _label(u.firstName, AppColors.ink),
          ],
        );
      case 'issue':
        final it = _repo.issueByPubId(widget.id);
        if (it == null) return _broken(widget.id);
        final meta = typeMeta(it.type);
        final color = KbTokens.issueChipColor(meta.hue);
        return _chipShell(
          background: AppColors.surfaceMuted,
          border: _hovered ? color : AppColors.hairline,
          children: [
            Icon(lucideIcon(meta.icon), size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              widget.id,
              style: TextStyle(
                fontFamily: AppTheme.fontMono,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        );
      case 'doc':
      default:
        final a = _repo.articleById(widget.id);
        if (a == null) return _broken('Missing article');
        return _chipShell(
          background: AppColors.surfaceMuted,
          border: _hovered ? AppColors.accentLine : AppColors.hairline,
          children: [
            Icon(lucideIcon(a.icon), size: 13, color: KbTokens.accent),
            const SizedBox(width: 4),
            _label(a.title, AppColors.ink),
          ],
        );
    }
  }

  Widget _label(String text, Color color) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );

  Widget _chipShell({
    required Color background,
    required Color border,
    required List<Widget> children,
    double padStart = 5,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      padding: EdgeInsets.fromLTRB(padStart, 1, 6, 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KbTokens.radiusChip),
        border: Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _broken(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(KbTokens.radiusChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(lucideIcon('unlink'), size: 12, color: AppColors.danger),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      );

  // ── preview content ──
  Widget? _buildPreviewCard() {
    if (widget.kind == 'issue') {
      final it = _repo.issueByPubId(widget.id);
      if (it == null) return null;
      final tm = typeMeta(it.type);
      final sm = stateMeta(it.state);
      final assignee = it.assigneeId == null ? null : _repo.userById(it.assigneeId!);
      final pm = priorityMeta(it.priority);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _typeGlyph(tm),
              const SizedBox(width: 9),
              Text(widget.id,
                  style: TextStyle(
                      fontFamily: AppTheme.fontMono,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft)),
              const Spacer(),
              _stateChip(sm),
            ],
          ),
          const SizedBox(height: 8),
          Text(it.title,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  letterSpacing: -0.1)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (assignee != null)
                _metaItem(AppAvatar(name: assignee.name, radius: 9),
                    assignee.firstName),
              _metaItem(
                  Icon(lucideIcon(pm.icon), size: 13, color: AppColors.inkSoft),
                  pm.label),
              if (it.tags.isNotEmpty) _tag(it.tags.first),
            ],
          ),
          _footer('Open issue'),
        ],
      );
    }
    final a = _repo.articleById(widget.id);
    if (a == null) return null;
    final sp = _repo.spaceById(a.spaceId);
    final author = _repo.userById(a.authorId);
    final excerpt = _excerpt(a.body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(lucideIcon(a.icon), size: 15, color: KbTokens.accent),
            ),
            const SizedBox(width: 9),
            if (sp != null)
              Flexible(
                child: Text(sp.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: KbTokens.spaceChipText(sp.hue))),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(a.title,
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
                letterSpacing: -0.1)),
        const SizedBox(height: 7),
        Text('$excerpt…',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.inkSoft, height: 1.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (author != null)
              _metaItem(
                  AppAvatar(name: author.name, radius: 9), author.firstName),
            _metaItem(
                Icon(lucideIcon('clock'), size: 13, color: AppColors.inkFaint),
                '${a.updated} ago'),
            _metaItem(Icon(lucideIcon('eye'), size: 13, color: AppColors.inkFaint),
                '${a.reads}'),
          ],
        ),
        _footer('Open article'),
      ],
    );
  }

  Widget _typeGlyph(TypeMeta tm) {
    final color = KbTokens.issueChipColor(tm.hue);
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Icon(lucideIcon(tm.icon), size: 13, color: color),
    );
  }

  Widget _stateChip(StateMeta sm) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                color: KbTokens.stateDot(sm.hue), shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(sm.name,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: KbTokens.stateInk(sm.hue))),
        ],
      );

  Widget _metaItem(Widget leading, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
        ],
      );

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(KbTokens.radiusChip),
          border: Border.all(color: AppColors.hairline2),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
      );

  Widget _footer(String label) => Padding(
        padding: const EdgeInsets.only(top: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(height: 1, color: AppColors.hairline2),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(lucideIcon('corner-down-left'),
                    size: 13, color: KbTokens.accent),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: KbTokens.accent)),
              ],
            ),
          ],
        ),
      );

  static String _excerpt(String body) {
    final cleaned = body
        .replaceAll(RegExp(r'\{\{[^}]+\}\}'), '')
        .replaceAll(RegExp(r'[#>*`|\-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
  }
}

/// The floating card shell: surface, hairline, card radius, pop shadow + the
/// reference enter animation (opacity 0→1, translateY −4→0, 160 ms), honoring
/// reduced-motion.
class _SmartPreview extends StatefulWidget {
  const _SmartPreview({required this.child});
  final Widget child;

  @override
  State<_SmartPreview> createState() => _SmartPreviewState();
}

class _SmartPreviewState extends State<_SmartPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 160))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final card = Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(KbTokens.radiusCard),
          border: Border.all(color: AppColors.hairline),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyDeep.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
    if (reduce) return card;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: _c.value,
        child: Transform.translate(
            offset: Offset(0, -4 * (1 - _c.value)), child: child),
      ),
      child: card,
    );
  }
}
