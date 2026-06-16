import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/models/work_models.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hive_widgets.dart';
import '../sprint_format.dart';
import '../sprint_tokens.dart';

/// Per-assignee load row for the capacity strip.
typedef CapacityPerson = ({String userId, String name, int done, int total});

/// The active-sprint Liquid-Glass header: translucent panel over the colourful
/// board with the sprint goal, a points/issues/days stat strip, a per-assignee
/// capacity strip and a day-countdown ring + "Complete sprint" action.
/// Collapses to a single column below the phone breakpoint (no overflow).
class GlassSprintHeader extends StatelessWidget {
  const GlassSprintHeader({
    super.key,
    required this.sprint,
    required this.committed,
    required this.donePoints,
    required this.issuesDone,
    required this.issuesTotal,
    required this.capacity,
    required this.onComplete,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  final Sprint sprint;
  final int committed;
  final int donePoints;
  final int issuesDone;
  final int issuesTotal;
  final List<CapacityPerson> capacity;
  final VoidCallback onComplete;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final day = sprintDay(sprint.startDate, sprint.endDate);
    final dayIndex = day?.day ?? 0;
    final dayTotal = day?.total ?? 0;
    final daysLeft = dayTotal - dayIndex;
    final ringP = dayTotal == 0 ? 0.0 : dayIndex / dayTotal;
    final brightness = Theme.of(context).brightness;
    final tint = SprintTokens.headerTint(brightness);
    final stacked = context.isCompact;

    if (collapsed) {
      return _CollapsedBar(
        sprint: sprint,
        dayIndex: dayIndex,
        dayTotal: dayTotal,
        ringP: ringP,
        tint: tint,
        brightness: brightness,
        onExpand: onToggleCollapsed,
      );
    }

    final main = _mainColumn(context, daysLeft);
    final side = _sideColumn(context, dayIndex, dayTotal, ringP);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: tint,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: brightness == Brightness.dark ? 0.12 : 0.7),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D191637),
                blurRadius: 40,
                offset: Offset(0, 14),
                spreadRadius: -18,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Faint honey/indigo glows behind the content.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const RadialGradient(
                        center: Alignment(-0.8, -1),
                        radius: 1.1,
                        colors: [Color(0x33D9A032), Color(0x00D9A032)],
                      ),
                    ),
                  ),
                ),
              ),
              // Padding so the content clears the collapse button top-right.
              Padding(
                padding: const EdgeInsets.only(right: 40),
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [main, const SizedBox(height: 18), side],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: main),
                          const SizedBox(width: 22),
                          side,
                        ],
                      ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: _GlassToggle(
                  icon: Icons.unfold_less_rounded,
                  tooltip: context.t('sprint.collapse'),
                  onTap: onToggleCollapsed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainColumn(BuildContext context, int daysLeft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF2A2410)),
                  const SizedBox(width: 4),
                  Text(
                    context.t('board.active'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A2410),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sprint.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontBrand,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
        if ((sprint.goal ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.adjust_rounded,
                    size: 16, color: AppColors.accentStrong),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sprint.goal!,
                  style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 22,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _stat(context, '$donePoints', ' / $committed',
                context.t('sprint.pointsDoneLabel')),
            _stat(context, '$issuesDone', ' / $issuesTotal',
                context.t('sprint.issuesDoneLabel')),
            _stat(context, '${daysLeft}d', null,
                context.t('sprint.remaining'),
                late: daysLeft <= 2),
          ],
        ),
        if (capacity.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final p in capacity) ...[
            _CapacityPersonRow(person: p),
            const SizedBox(height: 7),
          ],
        ],
      ],
    );
  }

  Widget _stat(BuildContext context, String value, String? sub, String label,
      {bool late = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontFamily: AppTheme.fontBrand,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: late ? AppColors.danger : AppColors.ink,
                ),
              ),
              if (sub != null)
                TextSpan(
                  text: sub,
                  style: TextStyle(
                    fontFamily: AppTheme.fontBrand,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
        ),
      ],
    );
  }

  Widget _sideColumn(
      BuildContext context, int dayIndex, int dayTotal, double ringP) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 116,
          height: 116,
          child: CustomPaint(
            painter: _RingPainter(
              progress: ringP,
              track: AppColors.inkFaint.withValues(alpha: 0.25),
              fill: AppColors.accentStrong,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$dayIndex',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontBrand,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.t('sprint.ofNDays', variables: {'total': '$dayTotal'}),
                    style: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onComplete,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            ),
          ),
          icon: const Icon(Icons.flag_rounded, size: 15),
          label: Text(context.t('sprint.completeSprint')),
        ),
      ],
    );
  }
}

/// Small translucent square button used for collapse / expand on the glass.
class _GlassToggle extends StatelessWidget {
  const _GlassToggle({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, size: 18, color: AppColors.inkSoft),
        ),
      ),
    );
  }
}

/// The collapsed active-sprint header: a compact glass bar with the Active
/// badge, name + goal, a thin day-progress track and an expand chevron.
/// Tapping anywhere expands it. Hugs its content on desktop, full-width on
/// phones (mirrors `.glasshead.collapsed` / `.ghc` in sprint.css).
class _CollapsedBar extends StatelessWidget {
  const _CollapsedBar({
    required this.sprint,
    required this.dayIndex,
    required this.dayTotal,
    required this.ringP,
    required this.tint,
    required this.brightness,
    required this.onExpand,
  });

  final Sprint sprint;
  final int dayIndex;
  final int dayTotal;
  final double ringP;
  final List<Color> tint;
  final Brightness brightness;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF2A2410)),
          const SizedBox(width: 4),
          Text(
            context.t('board.active'),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A2410),
            ),
          ),
        ],
      ),
    );

    final id = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sprint.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTheme.fontBrand,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.15,
          ),
        ),
        if ((sprint.goal ?? '').isNotEmpty)
          Text(
            sprint.goal!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
      ],
    );

    final chevron = _GlassToggle(
      icon: Icons.expand_more_rounded,
      tooltip: context.t('sprint.expand'),
      onTap: onExpand,
    );

    Widget progress({required bool fill}) {
      final track = ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 8,
          child: Row(
            children: [
              Expanded(
                flex: (ringP * 1000).round(),
                child: ColoredBox(color: AppColors.accent),
              ),
              Expanded(
                flex: ((1 - ringP) * 1000).round(),
                child: ColoredBox(
                  color: AppColors.inkFaint.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),
      );
      final label = Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          children: [
            const TextSpan(text: 'Day '),
            TextSpan(
              text: '$dayIndex',
              style: TextStyle(
                fontFamily: AppTheme.fontMono,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            TextSpan(text: '/$dayTotal'),
          ],
        ),
      );
      return Row(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          fill
              ? Expanded(child: track)
              : SizedBox(width: 168, child: track),
          const SizedBox(width: 10),
          label,
        ],
      );
    }

    final content = compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  badge,
                  const SizedBox(width: 12),
                  Expanded(child: id),
                  const SizedBox(width: 8),
                  chevron,
                ],
              ),
              if (dayTotal > 0) ...[
                const SizedBox(height: 12),
                progress(fill: true),
              ],
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              badge,
              const SizedBox(width: 14),
              Flexible(child: id),
              const SizedBox(width: 16),
              if (dayTotal > 0) ...[
                progress(fill: false),
                const SizedBox(width: 12),
              ],
              chevron,
            ],
          );

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: tint,
            ),
            border: Border.all(
              color: Colors.white
                  .withValues(alpha: brightness == Brightness.dark ? 0.12 : 0.7),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33191637),
                blurRadius: 30,
                offset: Offset(0, 10),
                spreadRadius: -16,
              ),
            ],
          ),
          child: content,
        ),
      ),
    );

    final tappable = GestureDetector(
      onTap: onExpand,
      behavior: HitTestBehavior.opaque,
      child: bar,
    );
    // Hug content on desktop (left-aligned), full width on phones.
    return compact
        ? tappable
        : Align(alignment: Alignment.centerLeft, child: tappable);
  }
}

class _CapacityPersonRow extends StatelessWidget {
  const _CapacityPersonRow({required this.person});

  final CapacityPerson person;

  @override
  Widget build(BuildContext context) {
    final total = person.total;
    final doneFrac = total == 0 ? 0.0 : person.done / total;
    return Row(
      children: [
        HiveAvatar(name: person.userId, size: 22),
        const SizedBox(width: 10),
        SizedBox(
          width: 84,
          child: Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  Expanded(
                    flex: (doneFrac * 1000).round(),
                    child: ColoredBox(color: SprintTokens.done),
                  ),
                  Expanded(
                    flex: ((1 - doneFrac) * 1000).round(),
                    child: ColoredBox(
                      color: total == 0
                          ? AppColors.canvas2
                          : SprintTokens.progress,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 58,
          child: Text(
            '${person.done}/$total pts',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppTheme.fontMono,
              fontSize: 11,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = fill
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fill != fill;
}
