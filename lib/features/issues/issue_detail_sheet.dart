import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../../core/api/api_client.dart';
import '../../core/api/hivora_repository.dart';
import '../../core/blocs/auth_bloc.dart';
import '../../core/i18n/i18n.dart';
import '../../core/models/core_models.dart';
import '../../core/models/work_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hive_widgets.dart';
import '../../core/widgets/soft_card.dart';
import 'issue_form.dart';
import 'work_log_sheet.dart';

/// Centered dialog that can grow much wider than the wolt default so the
/// two-column issue detail has room on desktop.
class _WideDialogType extends WoltDialogType {
  const _WideDialogType();

  @override
  BoxConstraints layoutModal(Size availableSize) {
    const pad = 48.0;
    final width =
        math.min(940.0, math.max(360.0, availableSize.width - pad * 2));
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: 0,
      maxHeight: math.max(360, availableSize.height * 0.88),
    );
  }
}

/// Opens the issue detail as a responsive wolt modal sheet (bottom sheet on
/// phones, wide centered dialog on desktop). The readable id + actions live in
/// the modal's own top bar; [onChanged] fires whenever the issue is edited or
/// deleted so the caller can refresh its list.
Future<void> showIssueDetailSheet(
  BuildContext context, {
  required String issueId,
  VoidCallback? onChanged,
}) {
  final repository = context.read<HivoraRepository>();
  final auth = context.read<AuthBloc>();
  final header = ValueNotifier<Issue?>(null);
  final bodyKey = GlobalKey<IssueDetailBodyState>();

  return WoltModalSheet.show<void>(
    context: context,
    // Push onto the root navigator so the sheet covers the floating glass
    // bottom-nav instead of rendering behind it (the shell nav is a Positioned
    // sibling inside the ShellRoute's nested navigator).
    useRootNavigator: true,
    barrierDismissible: true,
    modalTypeBuilder: (ctx) => MediaQuery.sizeOf(ctx).width >= 760
        ? const _WideDialogType()
        : WoltModalType.bottomSheet(),
    pageListBuilder: (modalContext) => [
      WoltModalSheetPage(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        hasTopBarLayer: true,
        isTopBarLayerAlwaysVisible: true,
        topBarTitle: ValueListenableBuilder<Issue?>(
          valueListenable: header,
          builder: (_, issue, _) => issue == null
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IdMono(issue.readableId, color: AppColors.inkSoft),
                    const SizedBox(width: 10),
                    Flexible(child: StateDotBadge(state: issue.state)),
                  ],
                ),
        ),
        trailingNavBarWidget: _SheetActions(
          onEdit: () => bodyKey.currentState?.editIssue(),
          onDelete: () => bodyKey.currentState?.confirmDeleteIssue(),
          onClose: () => Navigator.of(modalContext).maybePop(),
        ),
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: repository),
            BlocProvider.value(value: auth),
          ],
          child: IssueDetailBody(
            key: bodyKey,
            issueId: issueId,
            onChanged: onChanged,
            header: header,
          ),
        ),
      ),
    ],
  ).whenComplete(header.dispose);
}

/// Edit / delete / close actions rendered in the wolt top bar.
class _SheetActions extends StatelessWidget {
  const _SheetActions({
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.t('issues.edit'),
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded,
              size: 19, color: AppColors.inkSoft),
        ),
        IconButton(
          tooltip: context.t('common.delete'),
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded,
              size: 20, color: AppColors.danger),
        ),
        IconButton(
          tooltip: context.t('common.cancel'),
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded,
              size: 20, color: AppColors.inkSoft),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Shared editable issue detail — used both inside the sheet and by the
/// `/issues/:id` route. When [header] is supplied (sheet mode) the readable id
/// lives in the wolt top bar and the internal top bar is hidden.
class IssueDetailBody extends StatefulWidget {
  const IssueDetailBody({
    super.key,
    required this.issueId,
    this.onChanged,
    this.header,
  });

  final String issueId;
  final VoidCallback? onChanged;
  final ValueNotifier<Issue?>? header;

  @override
  State<IssueDetailBody> createState() => IssueDetailBodyState();
}

class IssueDetailBodyState extends State<IssueDetailBody> {
  final _comment = TextEditingController();

  Issue? _issue;
  List<IssueComment> _comments = const [];
  List<WorkItem> _workItems = const [];
  Project? _project;
  List<DirectoryUser> _users = const [];
  List<Sprint> _sprints = const [];
  Map<String, String> get _names =>
      {for (final u in _users) u.id: u.displayName};

  bool _loading = true;
  String? _error;
  bool _busy = false;

  HivoraRepository get _repo => context.read<HivoraRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final issue = await _repo.issue(widget.issueId);
      final results = await Future.wait([
        _repo.comments(widget.issueId),
        _repo.workItems(widget.issueId),
        _repo.projects(),
        _repo.users(),
      ]);
      _issue = issue;
      _comments = results[0] as List<IssueComment>;
      _workItems = results[1] as List<WorkItem>;
      _project = (results[2] as List<Project>)
          .where((p) => p.id == issue.projectId)
          .firstOrNull;
      _users = results[3] as List<DirectoryUser>;
      // Sprints come from the project's board(s); best-effort.
      try {
        final boards = await _repo.boards(projectId: issue.projectId);
        if (boards.isNotEmpty) {
          final view = await _repo.boardView(boards.first.id);
          _sprints = view.sprints;
        }
      } catch (_) {
        _sprints = const [];
      }
      widget.header?.value = issue;
      if (mounted) setState(() => _loading = false);
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = failure.message;
        });
      }
    }
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    setState(() => _busy = true);
    try {
      final updated = await _repo.updateIssue(widget.issueId, patch);
      _issue = updated;
      widget.header?.value = updated;
      widget.onChanged?.call();
    } on ApiFailure catch (failure) {
      _toast(failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    try {
      await _repo.addComment(widget.issueId, text);
      _comment.clear();
      _comments = await _repo.comments(widget.issueId);
      if (mounted) setState(() {});
    } on ApiFailure catch (failure) {
      _toast(failure.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Public entry points so the wolt top-bar actions can drive the body.
  Future<void> editIssue() async {
    final issue = _issue;
    if (issue == null) return;
    await showIssueForm(context, existing: issue);
    widget.onChanged?.call();
    await _load();
  }

  Future<void> confirmDeleteIssue() async {
    final issue = _issue;
    if (issue != null) await _confirmDelete(issue);
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading && _issue == null) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator(color: AppColors.navy)),
      );
    }
    if (_error != null && _issue == null) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t(_error!),
                  style: const TextStyle(color: AppColors.inkSoft)),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: _load, child: Text(context.t('common.retry'))),
            ],
          ),
        ),
      );
    }

    final issue = _issue!;
    // The wolt sheet (header != null) owns the top bar; the route renders its
    // own. Both are intrinsically sized — the route wraps this in a scroll view,
    // the sheet scrolls its own content.
    final inSheet = widget.header != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!inSheet)
          _RouteTopBar(
            issue: issue,
            busy: _busy,
            onEdit: editIssue,
            onDelete: () => _confirmDelete(issue),
            onClose: () => Navigator.of(context).maybePop(),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, inSheet ? 8 : 4, 20, 24),
          child: LayoutBuilder(
            builder: (context, c) {
              final left = <Widget>[
                _titleCard(issue),
                const SizedBox(height: 14),
                _commentsCard(),
              ];
              final right = <Widget>[
                _detailsCard(issue),
                const SizedBox(height: 14),
                _timeCard(issue),
              ];
              if (c.maxWidth >= 680) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: left),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 2,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: right),
                    ),
                  ],
                );
              }
              // Stacked (phone): title, details, time, comments.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _titleCard(issue),
                  const SizedBox(height: 14),
                  _detailsCard(issue),
                  const SizedBox(height: 14),
                  _timeCard(issue),
                  const SizedBox(height: 14),
                  _commentsCard(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _titleCard(Issue issue) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(issue.title,
              style: const TextStyle(
                  fontFamily: AppTheme.fontBrand,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.25)),
          if (issue.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in issue.tags) LabelTag(t)],
            ),
          ],
          if ((issue.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(issue.description!,
                style: const TextStyle(height: 1.55, color: AppColors.ink)),
          ],
        ],
      ),
    );
  }

  Widget _detailsCard(Issue issue) {
    final assigneeName =
        issue.assigneeId != null ? _names[issue.assigneeId!] : null;
    final reporterName =
        issue.reporterId != null ? _names[issue.reporterId!] : null;
    final me = context.read<AuthBloc>().state.user;
    final sprintName = issue.sprintId != null
        ? _sprints.where((s) => s.id == issue.sprintId).firstOrNull?.name
        : null;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('issues.details'),
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          // Status
          _DetailRow(
            label: context.t('issues.status'),
            onTap: _pickStatus,
            child: StateDotBadge(state: issue.state),
          ),
          // Assignee + "assign to me"
          _DetailRow(
            label: context.t('issues.assignee'),
            onTap: _pickAssignee,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _person(assigneeName, fallback: context.t('issues.unassigned')),
                if (me != null && issue.assigneeId != me.id) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _patch({'assigneeId': me.id}),
                    child: Text(context.t('issues.assignToMe'),
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.stTodo)),
                  ),
                ],
              ],
            ),
          ),
          // Priority
          _DetailRow(
            label: context.t('issues.priority'),
            onTap: _pickPriority,
            child: PriorityFlag(priority: issue.priority, withLabel: true),
          ),
          // Type (read-only)
          _DetailRow(
            label: context.t('issues.type'),
            child: TypeBadge(type: issue.type),
          ),
          // Sprint
          _DetailRow(
            label: context.t('issues.sprint'),
            onTap: _sprints.isEmpty ? null : _pickSprint,
            child: Text(
              sprintName ?? context.t('issues.noSprint'),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sprintName != null
                      ? AppColors.stTodo
                      : AppColors.inkFaint),
            ),
          ),
          // Author / reporter (read-only)
          _DetailRow(
            label: context.t('issues.author'),
            child: _person(reporterName, fallback: context.t('issues.unassigned')),
          ),
          // Start date
          _DetailRow(
            label: context.t('issues.startDate'),
            onTap: () => _pickDate(isStart: true),
            child: _dateValue(issue.startDate, isStart: true),
          ),
          // Due date
          _DetailRow(
            label: context.t('issues.dueDate'),
            onTap: () => _pickDate(isStart: false),
            last: true,
            child: _dateValue(issue.dueDate, isStart: false),
          ),
        ],
      ),
    );
  }

  Widget _person(String? name, {required String fallback}) {
    if (name == null || name.isEmpty) {
      return Text(fallback,
          style: const TextStyle(fontSize: 13, color: AppColors.inkFaint));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HiveAvatar(name: name, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _dateValue(DateTime? date, {required bool isStart}) {
    if (date == null) {
      return Text(context.t('issues.noValue'),
          style: const TextStyle(fontSize: 13, color: AppColors.inkFaint));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          MaterialLocalizations.of(context).formatMediumDate(date),
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _patch(
              {isStart ? 'clearStartDate' : 'clearDueDate': true}),
          child: const Icon(Icons.close_rounded,
              size: 15, color: AppColors.inkFaint),
        ),
      ],
    );
  }

  Widget _timeCard(Issue issue) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(context.t('issues.timeTracking'),
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: () async {
                  final logged = await showWorkLogSheet(context, issue.id);
                  if (logged == true) {
                    widget.onChanged?.call();
                    await _load();
                  }
                },
                child: Text(context.t('issues.logTime'),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentStrong)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t('issues.spent', variables: {
              'spent': fmtDuration(issue.spentMinutes),
              'estimate': fmtDuration(issue.estimateMinutes),
            }),
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
          for (final item in _workItems.take(8))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.timelapse_rounded,
                      size: 16, color: AppColors.accentStrong),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${fmtDuration(item.durationMinutes)} · ${item.activityType}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  if (item.date != null)
                    Text(
                      MaterialLocalizations.of(context)
                          .formatShortDate(item.date!),
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.inkFaint),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _commentsCard() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('issues.comments'),
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final comment in _comments)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(color: AppColors.hairline2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comment.text,
                      style: const TextStyle(height: 1.45, fontSize: 13)),
                  if (comment.createdAt != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      MaterialLocalizations.of(context)
                          .formatShortDate(comment.createdAt!.toLocal()),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.inkFaint),
                    ),
                  ],
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _comment,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: context.t('issues.addComment'),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.navy),
                onPressed: _submitComment,
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── pickers ────────────────────────────────────────────────────────────

  Future<void> _pickStatus() async {
    final states = _project?.workflowStates ?? [_issue!.state];
    final chosen = await _showOptions<String>(
      title: context.t('issues.status'),
      options: [
        for (final s in states)
          (value: s, child: StateDotBadge(state: s)),
      ],
    );
    if (chosen != null) await _patch({'state': chosen});
  }

  Future<void> _pickPriority() async {
    const priorities = ['SHOWSTOPPER', 'CRITICAL', 'MAJOR', 'NORMAL', 'MINOR'];
    final chosen = await _showOptions<String>(
      title: context.t('issues.priority'),
      options: [
        for (final p in priorities)
          (value: p, child: PriorityFlag(priority: p, withLabel: true)),
      ],
    );
    if (chosen != null) await _patch({'priority': chosen});
  }

  static const _noSprint = '__none__';

  Future<void> _pickSprint() async {
    final chosen = await _showOptions<String>(
      title: context.t('issues.sprint'),
      options: [
        (
          value: _noSprint,
          child: Text(context.t('issues.noSprint'),
              style: const TextStyle(color: AppColors.inkFaint))
        ),
        for (final s in _sprints) (value: s.id, child: Text(s.name)),
      ],
    );
    if (chosen != null) {
      // Empty string clears the sprint server-side (null is ignored by PATCH).
      await _patch({'sprintId': chosen == _noSprint ? '' : chosen});
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _issue!.startDate : _issue!.dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final iso = picked.toIso8601String().substring(0, 10);
      await _patch({isStart ? 'startDate' : 'dueDate': iso});
    }
  }

  Future<void> _pickAssignee() async {
    final me = context.read<AuthBloc>().state.user;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _PeoplePicker(
        users: _users,
        meId: me?.id,
        onUnassign: () {
          Navigator.of(sheetContext).pop();
          // Empty string clears the assignee (PATCH ignores null).
          _patch({'assigneeId': ''});
        },
        onAssignMe: me == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                _patch({'assigneeId': me.id});
              },
        onSelect: (id) {
          Navigator.of(sheetContext).pop();
          _patch({'assigneeId': id});
        },
      ),
    );
  }

  Future<T?> _showOptions<T>({
    required String title,
    required List<({T value, Widget child})> options,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            for (final o in options)
              InkWell(
                onTap: () => Navigator.of(sheetContext).pop(o.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Align(
                      alignment: Alignment.centerLeft, child: o.child),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Issue issue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(dialogContext.t('issues.deleteTitle')),
        content: Text(dialogContext
            .t('issues.deleteBody', variables: {'id': issue.readableId})),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.t('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _repo.deleteIssue(issue.id);
        widget.onChanged?.call();
        if (mounted) Navigator.of(context).maybePop();
      } on ApiFailure catch (failure) {
        _toast(failure.message);
      }
    }
  }
}

// ─────────────────────────── Detail row ────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.child,
    this.onTap,
    this.last = false,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.hairline2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.inkSoft)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
            if (onTap != null)
              const Icon(Icons.unfold_more_rounded,
                  size: 16, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Top bar ───────────────────────────────────────

class _RouteTopBar extends StatelessWidget {
  const _RouteTopBar({
    required this.issue,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  final Issue issue;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded,
                size: 20, color: AppColors.inkSoft),
          ),
          IdMono(issue.readableId, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          StateDotBadge(state: issue.state),
          if (busy) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent),
            ),
          ],
          const Spacer(),
          IconButton(
            tooltip: context.t('issues.edit'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded,
                size: 19, color: AppColors.inkSoft),
          ),
          IconButton(
            tooltip: context.t('common.delete'),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 20, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── People picker ─────────────────────────────────

class _PeoplePicker extends StatefulWidget {
  const _PeoplePicker({
    required this.users,
    required this.meId,
    required this.onSelect,
    required this.onUnassign,
    required this.onAssignMe,
  });

  final List<DirectoryUser> users;
  final String? meId;
  final ValueChanged<String> onSelect;
  final VoidCallback onUnassign;
  final VoidCallback? onAssignMe;

  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.users
        : widget.users
            .where((u) =>
                u.displayName.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q))
            .toList();
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(99)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: context.t('issues.searchPeople'),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (widget.onAssignMe != null && q.isEmpty)
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.accentSoft,
                        child: Icon(Icons.person_rounded,
                            color: AppColors.accentStrong, size: 18),
                      ),
                      title: Text(context.t('issues.assignToMe'),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: widget.onAssignMe,
                    ),
                  if (q.isEmpty)
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.canvas2,
                        child: Icon(Icons.block_rounded,
                            color: AppColors.inkSoft, size: 18),
                      ),
                      title: Text(context.t('issues.unassign')),
                      onTap: widget.onUnassign,
                    ),
                  if (q.isEmpty) const Divider(height: 1),
                  for (final u in filtered)
                    ListTile(
                      leading: HiveAvatar(name: u.displayName, size: 34),
                      title: Text(u.displayName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('@${u.username}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: u.id == widget.meId
                          ? const Icon(Icons.star_rounded,
                              size: 16, color: AppColors.accent)
                          : null,
                      onTap: () => widget.onSelect(u.id),
                    ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(context.t('issues.empty'),
                            style:
                                const TextStyle(color: AppColors.inkFaint)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
