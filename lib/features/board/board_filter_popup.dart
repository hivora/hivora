import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, LiquidGlassSettings, LiquidRoundedSuperellipse;

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hive_widgets.dart';
import '../search/search_tokens.dart';
import 'board_filter.dart';

const double _kCompactBreakpoint = 610;

/// Opens the board filter as a liquid-glass popover anchored to the filter
/// button (read from [anchorKey]). Mirrors the global-search glass look but is
/// a button-anchored popover, not a centered modal. Every chip toggle applies
/// live through [onChanged].
Future<void> openBoardFilter(
  BuildContext context, {
  required GlobalKey anchorKey,
  required BoardFilter filter,
  required BoardFilterOptions options,
  required Map<String, String> names,
  required ValueChanged<BoardFilter> onChanged,
}) {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final Rect anchorRect = (box != null && box.hasSize)
      ? (box.localToGlobal(Offset.zero) & box.size)
      : Rect.zero;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => _BoardFilterDialog(
      anchorRect: anchorRect,
      initial: filter,
      options: options,
      names: names,
      onChanged: onChanged,
    ),
    transitionBuilder: (_, _, _, child) => child,
  );
}

class _BoardFilterDialog extends StatefulWidget {
  const _BoardFilterDialog({
    required this.anchorRect,
    required this.initial,
    required this.options,
    required this.names,
    required this.onChanged,
  });

  final Rect anchorRect;
  final BoardFilter initial;
  final BoardFilterOptions options;
  final Map<String, String> names;
  final ValueChanged<BoardFilter> onChanged;

  @override
  State<_BoardFilterDialog> createState() => _BoardFilterDialogState();
}

class _BoardFilterDialogState extends State<_BoardFilterDialog> {
  late BoardFilter _filter = widget.initial;

  void _toggle(BoardFilterFacet facet, String value) {
    setState(() => _filter = _filter.toggle(facet, value));
    widget.onChanged(_filter);
  }

  void _clear() {
    if (_filter.isEmpty) return;
    setState(() => _filter = BoardFilter.empty);
    widget.onChanged(_filter);
  }

  void _close() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SearchTokens.of(Theme.of(context).brightness);
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final compact = size.width < _kCompactBreakpoint;
    final anim = ModalRoute.of(context)!.animation!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    const margin = 12.0;
    final panelWidth = compact
        ? math.min(360.0, size.width - margin * 2)
        : 340.0;

    final anchor = widget.anchorRect;
    // Right-align the panel to the button, clamped on-screen.
    double left = anchor.right - panelWidth;
    left = left.clamp(
      margin,
      math.max(margin, size.width - panelWidth - margin),
    );

    final belowTop = anchor.bottom + 8;
    final roomBelow = size.height - belowTop - margin - pad.bottom;
    final roomAbove = anchor.top - 8 - margin - pad.top;
    final placeAbove = roomBelow < 240 && roomAbove > roomBelow;
    final maxHeight = (placeAbove ? roomAbove : roomBelow).clamp(180.0, 520.0);
    final top = placeAbove ? null : belowTop;
    final bottom = placeAbove ? (size.height - anchor.top + 8) : null;

    final panel = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: panelWidth, maxHeight: maxHeight),
      child: _shadowed(tokens, BorderRadius.circular(20), _glassPanel(tokens)),
    );

    return Stack(
      children: [
        // Tap-catcher to dismiss; popover keeps the app visible (no heavy blur).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          bottom: bottom,
          width: panelWidth,
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, child) {
              if (reduceMotion) {
                return Opacity(opacity: anim.value, child: child);
              }
              final t = const Cubic(
                0.34,
                1.3,
                0.64,
                1,
              ).transform(anim.value.clamp(0.0, 1.0));
              return Opacity(
                opacity: (anim.value / 0.6).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.92 + 0.08 * t,
                  alignment: placeAbove
                      ? Alignment.bottomRight
                      : Alignment.topRight,
                  child: child,
                ),
              );
            },
            child: panel,
          ),
        ),
      ],
    );
  }

  Widget _shadowed(SearchTokens tokens, BorderRadius radius, Widget child) =>
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: tokens.panelShadow,
        ),
        child: child,
      );

  Widget _glassPanel(SearchTokens tokens) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = Stack(
      children: [
        Material(type: MaterialType.transparency, child: _column(tokens)),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RimPainter(
                radius: 20,
                edge: tokens.edge,
                edgeSoft: tokens.edgeSoft,
              ),
            ),
          ),
        ),
      ],
    );
    return GlassContainer(
      useOwnLayer: true,
      clipBehavior: Clip.antiAlias,
      shape: const LiquidRoundedSuperellipse(borderRadius: 20),
      settings: LiquidGlassSettings(
        glassColor: tokens.tint,
        blur: 18,
        thickness: 16,
        saturation: 1.9,
        whitenStrength: dark ? 0.04 : 0.0,
        whitenGated: false,
        shadowElevation: 0,
      ),
      child: content,
    );
  }

  Widget _column(SearchTokens tokens) {
    final o = widget.options;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(tokens),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (o.states.isNotEmpty)
                  _section(
                    tokens,
                    label: context.t('board.filterSection.status'),
                    children: [
                      for (final s in o.states)
                        _chip(
                          tokens,
                          selected: _filter.states.contains(s),
                          onTap: () => _toggle(BoardFilterFacet.state, s),
                          child: _StateChipBody(state: s),
                        ),
                    ],
                  ),
                if (o.types.isNotEmpty)
                  _section(
                    tokens,
                    label: context.t('board.filterSection.type'),
                    children: [
                      for (final ty in o.types)
                        _chip(
                          tokens,
                          selected: _filter.types.contains(ty),
                          onTap: () => _toggle(BoardFilterFacet.type, ty),
                          child: _TypeChipBody(type: ty),
                        ),
                    ],
                  ),
                if (o.priorities.isNotEmpty)
                  _section(
                    tokens,
                    label: context.t('board.filterSection.priority'),
                    children: [
                      for (final p in o.priorities)
                        _chip(
                          tokens,
                          selected: _filter.priorities.contains(p),
                          onTap: () => _toggle(BoardFilterFacet.priority, p),
                          child: _PriorityChipBody(priority: p),
                        ),
                    ],
                  ),
                if (o.assignees.isNotEmpty)
                  _section(
                    tokens,
                    label: context.t('board.filterSection.assignee'),
                    children: [
                      for (final id in o.assignees)
                        _chip(
                          tokens,
                          selected: _filter.assignees.contains(id),
                          onTap: () => _toggle(BoardFilterFacet.assignee, id),
                          child: _AssigneeChipBody(
                            name: widget.names[id] ?? id,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(SearchTokens tokens) {
    final count = _filter.activeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, size: 16, color: tokens.inkSoft),
          const SizedBox(width: 8),
          Text(
            context.t('board.filterTitle'),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: tokens.ink,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontFamily: AppTheme.fontMono,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentStrong,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (count > 0)
            TextButton(
              onPressed: _clear,
              style: TextButton.styleFrom(
                foregroundColor: tokens.inkSoft,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(context.t('board.clearFilters')),
            ),
        ],
      ),
    );
  }

  Widget _section(
    SearchTokens tokens, {
    required String label,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: tokens.inkFaint,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: children),
        ],
      ),
    );
  }

  Widget _chip(
    SearchTokens tokens, {
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return _FilterChipShell(
      tokens: tokens,
      selected: selected,
      onTap: onTap,
      child: child,
    );
  }
}

/// Pill chip used inside the glass popup; honey-amber fill when selected.
class _FilterChipShell extends StatelessWidget {
  const _FilterChipShell({
    required this.tokens,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final SearchTokens tokens;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : tokens.field,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: selected ? AppColors.accentLine : tokens.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            if (selected) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.check_rounded,
                size: 13,
                color: AppColors.accentStrong,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── chip bodies ───────────────────────────────────────────────────────────

class _StateChipBody extends StatelessWidget {
  const _StateChipBody({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stateColor(state.toUpperCase());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          stateLabel(state),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TypeChipBody extends StatelessWidget {
  const _TypeChipBody({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TypeGlyph(type: type, size: 16),
        const SizedBox(width: 6),
        Text(
          _facetLabel(context, 'type', type),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _PriorityChipBody extends StatelessWidget {
  const _PriorityChipBody({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PriorityFlag(priority: priority),
        const SizedBox(width: 6),
        Text(
          _facetLabel(context, 'priority', priority),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _AssigneeChipBody extends StatelessWidget {
  const _AssigneeChipBody({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HiveAvatar(name: name, size: 18),
        const SizedBox(width: 6),
        Text(
          name,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Localised label for an enum-like [code] under [prefix] (`type`/`priority`),
/// humanising the raw code when no translation exists (e.g. legacy values).
String _facetLabel(BuildContext context, String prefix, String code) {
  final key = '$prefix.${code.toLowerCase()}';
  final value = context.t(key);
  if (value != key) return value;
  return code
      .split(RegExp(r'[_ ]'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// 1px specular rim (bright top-left → dim → bright) — matches the global
/// search panel's rim.
class _RimPainter extends CustomPainter {
  _RimPainter({
    required this.radius,
    required this.edge,
    required this.edgeSoft,
  });
  final double radius;
  final Color edge;
  final Color edgeSoft;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [edge, edgeSoft, Colors.transparent, edgeSoft],
        const [0.0, 0.28, 0.52, 1.0],
      );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius || old.edge != edge || old.edgeSoft != edgeSoft;
}
