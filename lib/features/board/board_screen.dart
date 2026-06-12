import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../../core/api/api_client.dart';
import '../../core/api/hivora_repository.dart';
import '../../core/i18n/i18n.dart';
import '../../core/models/work_models.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_widgets.dart';

// ─────────────────────────── BoardScreen ──────────────────────────────────
// Shown at /board — lists all boards across projects; can filter by project.
// Tapping a board card navigates to /boards/:id.

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  List<AgileBoard> _boards = const [];
  List<Project> _projects = const [];
  String? _projectFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = context.read<HivoraRepository>();
    try {
      final results = await Future.wait([
        repo.projects(),
        repo.boards(projectId: _projectFilter),
      ]);
      _projects = results[0] as List<Project>;
      _boards = results[1] as List<AgileBoard>;
      setState(() => _loading = false);
    } on ApiFailure catch (failure) {
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _showCreate() async {
    if (_projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('board.needsProject'))));
      return;
    }
    final repo = context.read<HivoraRepository>();
    final created = await WoltModalSheet.show<AgileBoard?>(
      context: context,
      pageListBuilder: (modalContext) => [
        WoltModalSheetPage(
          backgroundColor: AppColors.surface,
          hasTopBarLayer: false,
          child: RepositoryProvider.value(
            value: repo,
            child: _CreateBoardBody(
              projects: _projects,
              initialProjectId: _projectFilter,
            ),
          ),
        ),
      ],
    );
    if (created != null) {
      if (mounted) context.push('/boards/${created.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _boards.isEmpty && _error == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.navy));
    }
    if (_error != null && _boards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t(_error!),
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _load, child: Text(context.t('common.retry'))),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              context.pageGutter, 16, context.pageGutter, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('board.title'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_projects.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ProjectFilterChip(
                      projects: _projects,
                      selected: _projectFilter,
                      onChanged: (id) {
                        _projectFilter = id;
                        _load();
                      },
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _showCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF2A2410),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.t('board.newBoard')),
                ),
              ],
            ),
          ),
        ),
        if (_boards.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.view_kanban_rounded,
                      size: 56, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(context.t('board.empty'),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _showCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: const Color(0xFF2A2410),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(context.t('board.newBoard')),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.all(context.pageGutter),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.gridColumns(minTileWidth: 280),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                mainAxisExtent: 150,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _BoardListCard(
                  board: _boards[index],
                  index: index,
                  projects: _projects,
                ),
                childCount: _boards.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────── KanbanBoardScreen ────────────────────────────
// Shown at /boards/:id — the actual drag-and-drop kanban for one board.

class KanbanBoardScreen extends StatefulWidget {
  const KanbanBoardScreen({super.key, required this.boardId});

  final String boardId;

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  String? _sprintId;
  BoardView? _view;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final view = await context
          .read<HivoraRepository>()
          .boardView(widget.boardId, sprintId: _sprintId);
      setState(() {
        _view = view;
        _loading = false;
      });
    } on ApiFailure catch (failure) {
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _moveIssue(Issue issue, BoardColumnView column) async {
    if (column.states.contains(issue.state) || column.states.isEmpty) return;
    try {
      await context
          .read<HivoraRepository>()
          .updateIssue(issue.id, {'state': column.states.first});
      await _load();
    } on ApiFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _view == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.navy));
    }
    if (_error != null && _view == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t(_error!),
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _load, child: Text(context.t('common.retry'))),
          ],
        ),
      );
    }
    final view = _view!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              EdgeInsets.fromLTRB(context.pageGutter, 16, context.pageGutter, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Back link
              InkWell(
                onTap: () => context.canPop() ? context.pop() : context.go('/board'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded,
                          size: 18, color: AppColors.inkSoft),
                      const SizedBox(width: 4),
                      Text(context.t('board.boards'),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
              ),
              Text(
                view.board.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (view.sprints.isNotEmpty)
                DropdownButton<String?>(
                  value: _sprintId,
                  hint: Text(context.t('board.allSprints')),
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    DropdownMenuItem(
                        value: null,
                        child: Text(context.t('board.allSprints'))),
                    for (final sprint in view.sprints)
                      DropdownMenuItem(
                          value: sprint.id, child: Text(sprint.name)),
                  ],
                  onChanged: (value) {
                    _sprintId = value;
                    _load();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.all(context.pageGutter),
            itemCount: view.columns.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final column = view.columns[index];
              return _BoardColumn(
                column: column,
                onAccept: (issue) => _moveIssue(issue, column),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Board list card ──────────────────────────────

class _BoardListCard extends StatelessWidget {
  const _BoardListCard(
      {required this.board, required this.index, required this.projects});

  final AgileBoard board;
  final int index;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final projectNames = board.projectIds
        .map((id) => projects.firstWhere((p) => p.id == id,
            orElse: () => Project(id: id, key: id, name: id)))
        .map((p) => p.name)
        .join(', ');

    return SoftCard(
      color: AppColors.pastelFor(index),
      onTap: () => context.push('/boards/${board.id}'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.view_kanban_rounded,
                    size: 13, color: AppColors.navy),
                const SizedBox(width: 4),
                Text(
                  context.t('board.boardLabel'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              board.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          if (projectNames.isNotEmpty)
            Text(
              projectNames,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child:
                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Project filter chip ──────────────────────────

class _ProjectFilterChip extends StatelessWidget {
  const _ProjectFilterChip({
    required this.projects,
    required this.selected,
    required this.onChanged,
  });

  final List<Project> projects;
  final String? selected;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    final label = selected != null
        ? projects.firstWhere((p) => p.id == selected,
                orElse: () => projects.first)
            .name
        : context.t('board.allProjects');

    return PopupMenuButton<String?>(
      initialValue: selected,
      onSelected: onChanged,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 36),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: null,
          child: Text(context.t('board.allProjects')),
        ),
        ...projects.map(
          (p) => PopupMenuItem(value: p.id, child: Text(p.name)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 16, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Create Board dialog body ─────────────────────

class _CreateBoardBody extends StatefulWidget {
  const _CreateBoardBody({required this.projects, this.initialProjectId});

  final List<Project> projects;
  final String? initialProjectId;

  @override
  State<_CreateBoardBody> createState() => _CreateBoardBodyState();
}

class _CreateBoardBodyState extends State<_CreateBoardBody> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  late String _selectedProjectId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedProjectId =
        widget.initialProjectId ?? widget.projects.first.id;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 32 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('board.newBoard'),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration:
                  InputDecoration(labelText: context.t('board.name')),
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? context.t('errors.required')
                      : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedProjectId,
              decoration:
                  InputDecoration(labelText: context.t('board.project')),
              items: widget.projects
                  .map((p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedProjectId = value);
                }
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: const Color(0xFF2A2410),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF2A2410)),
                    )
                  : Text(context.t('common.create')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final board = await context.read<HivoraRepository>().createBoard(
            _name.text.trim(),
            [_selectedProjectId],
          );
      if (mounted) Navigator.of(context).pop(board);
    } on ApiFailure catch (failure) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
    }
  }
}

// ─────────────────────────── Kanban column ────────────────────────────────

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({required this.column, required this.onAccept});

  final BoardColumnView column;
  final void Function(Issue) onAccept;

  @override
  Widget build(BuildContext context) {
    final overWip =
        column.wipLimit != null && column.issues.length > column.wipLimit!;
    return SizedBox(
      width: 300,
      child: DragTarget<Issue>(
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidates, rejected) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: candidates.isNotEmpty
                  ? AppColors.pastelLavender.withValues(alpha: 0.5)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          column.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                      PillChip(
                        label: column.wipLimit != null
                            ? '${column.issues.length}/${column.wipLimit}'
                            : '${column.issues.length}',
                        background: overWip
                            ? AppColors.danger.withValues(alpha: 0.15)
                            : Colors.white,
                        foreground: overWip
                            ? AppColors.danger
                            : AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: column.issues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final issue = column.issues[index];
                      return LongPressDraggable<Issue>(
                        data: issue,
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 270,
                            child: _BoardCard(issue: issue, dragging: true),
                          ),
                        ),
                        childWhenDragging: Opacity(
                            opacity: 0.35,
                            child: _BoardCard(issue: issue)),
                        child: _BoardCard(issue: issue),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.issue, this.dragging = false});

  final Issue issue;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: dragging ? null : () => context.go('/issues/${issue.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            issue.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                issue.readableId,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Icon(Icons.flag_rounded,
                  size: 14, color: priorityColor(issue.priority)),
            ],
          ),
        ],
      ),
    );
  }
}
