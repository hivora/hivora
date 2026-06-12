import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/hivora_repository.dart';
import '../../core/blocs/fetch_cubit.dart';
import '../../core/i18n/i18n.dart';
import '../../core/models/content_models.dart';
import '../../core/models/work_models.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_widgets.dart';
import '../issues/issue_form.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FetchCubit<DashboardData>(context.read<HivoraRepository>().dashboard)..load(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchCubit<DashboardData>, FetchState<DashboardData>>(
      builder: (context, state) {
        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () => context.read<FetchCubit<DashboardData>>().load(),
          child: AsyncView(
            isLoading: state.isLoading,
            hasData: state.hasData,
            errorKey: state.errorKey,
            onRetry: () => context.read<FetchCubit<DashboardData>>().load(),
            builder: (context) {
              final data = state.data!;
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(context.pageGutter),
                child: context.isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(onCreate: () => showIssueForm(context)),
                          const SizedBox(height: 16),
                          _TodayTasks(issues: data.todayTasks),
                          const SizedBox(height: 16),
                          _CompletionCard(completion: data.completion),
                          const SizedBox(height: 16),
                          _RankCard(ranking: data.ranking),
                          const SizedBox(height: 16),
                          _TrackerCard(tracker: data.tracker),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(onCreate: () => showIssueForm(context)),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _TodayTasks(issues: data.todayTasks),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 2,
                                child: _CompletionCard(completion: data.completion),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _RankCard(ranking: data.ranking)),
                              const SizedBox(width: 20),
                              Expanded(child: _TrackerCard(tracker: data.tracker)),
                            ],
                          ),
                        ],
                      ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('dashboard.title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                context.t('dashboard.subtitle'),
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(context.t('issues.new')),
        ),
      ],
    );
  }
}

// ─────────────────────────── Today's tasks ─────────────────────────────────

class _TodayTasks extends StatelessWidget {
  const _TodayTasks({required this.issues});

  final List<Issue> issues;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: context.t('dashboard.todayTask'),
            actionLabel: context.t('common.seeAll'),
            onAction: () => context.go('/issues'),
          ),
          const SizedBox(height: 12),
          if (issues.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.t('dashboard.noTasks'),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: issues.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _TaskCard(issue: issues[index], index: index),
              ),
            ),
        ],
      ),
    );
  }
}

/// Accent color palette for task cards — warm tints that work with the new
/// paper canvas (replaces the old pastel set).
const _taskCardColors = [
  Color(0xFFF3E9D2), // amber soft
  Color(0xFFE9EEF8), // blue tint
  Color(0xFFE8F5EE), // green tint
  Color(0xFFF3ECF8), // purple tint
];

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.issue, required this.index});

  final Issue issue;
  final int index;

  @override
  Widget build(BuildContext context) {
    final progress = issue.estimateMinutes != null && issue.estimateMinutes! > 0
        ? (issue.spentMinutes / issue.estimateMinutes!).clamp(0.0, 1.0)
        : 0.0;
    final cardColor = _taskCardColors[index % _taskCardColors.length];
    final priorityCol = AppColors.priorityColor(issue.priority);
    return SizedBox(
      width: 220,
      child: SoftCard(
        color: cardColor,
        onTap: () => context.go('/issues/${issue.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PillChip(
              label: context.t('priority.${issue.priority.toLowerCase()}'),
              background: AppColors.soft(priorityCol),
              foreground: priorityCol,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                issue.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      curve: const Cubic(0.22, 1, 0.36, 1),
                      tween: Tween(begin: 0, end: progress),
                      builder: (_, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.6),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  issue.readableId,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Completion donut ──────────────────────────────

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.completion});

  final ProjectCompletion completion;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (context.t('dashboard.done'), completion.donePercent, AppColors.stDone),
      (
        context.t('dashboard.inProgress'),
        completion.inProgressPercent,
        AppColors.stProgress
      ),
      (
        context.t('dashboard.backlog'),
        completion.backlogPercent,
        AppColors.stBacklog
      ),
    ];
    final doneRounded = (completion.donePercent * 100).round();
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: context.t('dashboard.projectCompleted'),
            actionLabel: context.t('dashboard.totalIssues',
                variables: {'count': '${completion.total}'}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (label, percent, color) in entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(label,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.inkSoft, fontSize: 12)),
                            ),
                            Text(
                              '${(percent * 100).round()}%',
                              style: const TextStyle(
                                  fontFamily: AppTheme.fontMono,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Donut with centered label
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 36,
                        startDegreeOffset: -90,
                        sections: [
                          for (final (_, percent, color) in entries)
                            PieChartSectionData(
                              value: percent <= 0 ? 0.001 : percent,
                              color: color,
                              radius: 18,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    TweenAnimationBuilder<int>(
                      duration: const Duration(milliseconds: 900),
                      curve: const Cubic(0.22, 1, 0.36, 1),
                      tween: IntTween(begin: 0, end: doneRounded),
                      builder: (_, value, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$value%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontMono,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              height: 1,
                            ),
                          ),
                          const Text(
                            'done',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.inkSoft,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Rank leaderboard ──────────────────────────────

class _RankCard extends StatelessWidget {
  const _RankCard({required this.ranking});

  final List<RankEntry> ranking;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: context.t('dashboard.rankPerformance')),
          const SizedBox(height: 4),
          if (ranking.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(context.t('dashboard.noRanking'),
                  style: const TextStyle(color: AppColors.inkSoft)),
            ),
          for (final entry in ranking.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AppAvatar(
                name: entry.displayName,
                radius: 16,
              ),
              title: Text(entry.displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink)),
              subtitle: entry.title != null
                  ? Text(entry.title!,
                      style: const TextStyle(
                          color: AppColors.inkSoft, fontSize: 11))
                  : null,
              trailing: Text(
                context.t('dashboard.points',
                    variables: {'count': '${entry.points}'}),
                style: const TextStyle(
                  fontFamily: AppTheme.fontMono,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Weekly tracker bars ───────────────────────────

class _TrackerCard extends StatelessWidget {
  const _TrackerCard({required this.tracker});

  final List<TrackerDay> tracker;

  @override
  Widget build(BuildContext context) {
    final maxMinutes =
        tracker.fold<int>(60, (m, d) => d.focusMinutes > m ? d.focusMinutes : m);
    const days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: context.t('dashboard.trackerDetail'),
            actionLabel: context.t('common.seeAll'),
            onAction: () => context.go('/timesheet'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxMinutes / 60,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= tracker.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            days[(tracker[i].date.weekday - 1) % 7],
                            style: const TextStyle(
                              fontFamily: AppTheme.fontMono,
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < tracker.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: tracker[i].focusMinutes / 60,
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                          color: i.isEven ? AppColors.accent : AppColors.navy,
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxMinutes / 60,
                            color: AppColors.canvas2,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
