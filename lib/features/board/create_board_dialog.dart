import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_client.dart';
import '../../core/api/hinata_repository.dart';
import '../../core/blocs/app_config_bloc.dart';
import '../../core/i18n/i18n.dart';
import '../../core/models/work_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../sprint/modals/glass_modal.dart';

/// Liquid-Glass "Create board" modal. First asks the board type (Kanban —
/// continuous flow, default; or Scrum — sprint planning), then name + project.
/// Creates the board and returns it, or null when dismissed.
Future<AgileBoard?> showCreateBoardDialog(
  BuildContext context, {
  required List<Project> projects,
  String? initialProjectId,
}) {
  return showGlassModal<AgileBoard>(
    context,
    width: 560,
    builder: (_) => _CreateBoardBody(
      projects: projects,
      initialProjectId: initialProjectId,
    ),
  );
}

class _CreateBoardBody extends StatefulWidget {
  const _CreateBoardBody({required this.projects, this.initialProjectId});

  final List<Project> projects;
  final String? initialProjectId;

  @override
  State<_CreateBoardBody> createState() => _CreateBoardBodyState();
}

class _CreateBoardBodyState extends State<_CreateBoardBody> {
  final _name = TextEditingController();
  BoardType _type = BoardType.kanban;
  late final List<String> _projectIds = [
    widget.initialProjectId ?? widget.projects.first.id,
  ];
  bool _saving = false;
  String? _error;

  bool get _multiProject =>
      context.read<AppConfigBloc>().state.meta?.multiProjectBoards ?? false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final board = await context.read<HinataRepository>().createBoard(
        _name.text.trim(),
        List<String>.from(_projectIds),
        type: _type,
      );
      if (mounted) Navigator.of(context).pop(board);
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = failure.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassModalHeader(
          icon: LucideIcons.squareKanban,
          title: context.t('board.newBoard'),
          subtitle: context.t('board.createSub'),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassField(
                  label: context.t('board.chooseType'),
                  child: Column(
                    children: [
                      _TypeCard(
                        icon: LucideIcons.columns3,
                        title: context.t('board.typeKanban'),
                        description: context.t('board.typeKanbanDesc'),
                        selected: _type == BoardType.kanban,
                        onTap: () => setState(() => _type = BoardType.kanban),
                      ),
                      const SizedBox(height: 8),
                      _TypeCard(
                        icon: LucideIcons.zap,
                        title: context.t('board.typeScrum'),
                        description: context.t('board.typeScrumDesc'),
                        selected: _type == BoardType.scrum,
                        onTap: () => setState(() => _type = BoardType.scrum),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassField(
                  label: context.t('board.name'),
                  child: TextField(
                    controller: _name,
                    autofocus: true,
                    onSubmitted: (_) => _save(),
                    decoration: glassInputDecoration(),
                  ),
                ),
                const SizedBox(height: 16),
                GlassField(
                  label: context.t(
                      _multiProject ? 'board.linkedProjects' : 'board.project'),
                  child: _multiProject
                      ? ProjectPickerField(
                          projects: widget.projects,
                          selected: _projectIds,
                          onChanged: () => setState(() {}),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusControl,
                            ),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _projectIds.first,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusControl,
                              ),
                              items: [
                                for (final p in widget.projects)
                                  DropdownMenuItem(
                                      value: p.id, child: Text(p.name)),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _projectIds
                                    ..clear()
                                    ..add(v));
                                }
                              },
                            ),
                          ),
                        ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.t(_error!),
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        GlassModalFooter(
          confirmLabel: context.t('common.create'),
          busy: _saving,
          onConfirm: _name.text.trim().isEmpty ? null : _save,
        ),
      ],
    );
  }
}

/// A tappable field that summarises the chosen projects and opens a searchable
/// multi-select picker (consistent with the assignee people-picker). Mutates
/// [selected] in place (always keeping at least one) and notifies [onChanged].
class ProjectPickerField extends StatelessWidget {
  const ProjectPickerField({
    super.key,
    required this.projects,
    required this.selected,
    required this.onChanged,
  });

  final List<Project> projects;
  final List<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final chosen = projects.where((p) => selected.contains(p.id)).toList();
    final summary = chosen.isEmpty
        ? context.t('board.chooseProjects')
        : chosen.map((p) => p.key).join(', ');
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      onTap: () => showProjectPicker(
        context,
        projects: projects,
        selected: selected,
        onChanged: onChanged,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(color: AppColors.hairline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: chosen.isEmpty ? AppColors.inkFaint : AppColors.ink,
                ),
              ),
            ),
            Icon(LucideIcons.chevronsUpDown, size: 18, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}

/// Shows the searchable multi-select project picker — anchored popover on wide
/// screens, bottom sheet on phones — mirroring the assignee picker.
Future<void> showProjectPicker(
  BuildContext context, {
  required List<Project> projects,
  required List<String> selected,
  required VoidCallback onChanged,
}) async {
  final wide = MediaQuery.sizeOf(context).width >= kGlassPopoverBreakpoint;
  Widget picker(BuildContext _) => _ProjectSearchPicker(
        projects: projects,
        selected: selected,
        onChanged: onChanged,
        anchored: wide,
      );
  if (wide) {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context, rootOverlay: true)
        .context
        .findRenderObject() as RenderBox?;
    final anchor = (box != null && overlay != null)
        ? (box.localToGlobal(Offset.zero, ancestor: overlay) & box.size)
        : (Offset.zero & MediaQuery.sizeOf(context));
    await showGlassAnchoredPopover<void>(
      context,
      anchorRect: anchor,
      width: 340,
      maxHeight: 460,
      builder: picker,
    );
    return;
  }
  await showGlassBottomSheet<void>(context, showHandle: false, builder: picker);
}

/// Searchable, multi-select project list. Stays open and toggles selection
/// (checkmarks); keeps at least one project selected.
class _ProjectSearchPicker extends StatefulWidget {
  const _ProjectSearchPicker({
    required this.projects,
    required this.selected,
    required this.onChanged,
    this.anchored = false,
  });

  final List<Project> projects;
  final List<String> selected;
  final VoidCallback onChanged;
  final bool anchored;

  @override
  State<_ProjectSearchPicker> createState() => _ProjectSearchPickerState();
}

class _ProjectSearchPickerState extends State<_ProjectSearchPicker> {
  String _query = '';

  void _toggle(Project p) {
    final on = widget.selected.contains(p.id);
    if (on && widget.selected.length == 1) return; // keep at least one
    setState(() {
      if (on) {
        widget.selected.remove(p.id);
      } else {
        widget.selected.add(p.id);
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.projects
        : widget.projects
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                p.key.toLowerCase().contains(q))
            .toList();
    final searchField = Padding(
      padding: widget.anchored
          ? const EdgeInsets.fromLTRB(12, 12, 12, 8)
          : const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: TextField(
        autofocus: true,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(LucideIcons.search, size: 18),
          hintText: context.t('board.searchProjects'),
          filled: true,
          fillColor: AppColors.surfaceMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            borderSide: BorderSide(color: AppColors.hairline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            borderSide: BorderSide(color: AppColors.hairline),
          ),
        ),
      ),
    );
    final list = ListView(
      padding: EdgeInsets.only(bottom: widget.anchored ? 6 : 16),
      shrinkWrap: widget.anchored,
      children: [
        for (final p in filtered)
          ListTile(
            title: Text('${p.key} – ${p.name}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Icon(
              widget.selected.contains(p.id)
                  ? LucideIcons.checkSquare
                  : LucideIcons.square,
              size: 20,
              color: widget.selected.contains(p.id)
                  ? AppColors.accent
                  : AppColors.inkFaint,
            ),
            onTap: () => _toggle(p),
          ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(context.t('common.empty'),
                  style: TextStyle(color: AppColors.inkFaint)),
            ),
          ),
      ],
    );
    if (widget.anchored) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [searchField, Flexible(child: list)],
      );
    }
    return Column(
      children: [searchField, Expanded(child: list)],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentSoft
              : AppColors.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.hairline,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : AppColors.canvas2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 19,
                color: selected ? const Color(0xFF2A2410) : AppColors.inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                LucideIcons.circleCheckBig,
                size: 20,
                color: AppColors.accentStrong,
              ),
          ],
        ),
      ),
    );
  }
}
