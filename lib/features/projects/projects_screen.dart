import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/widgets/hive_loader.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../../core/api/api_client.dart';
import '../../core/api/hivora_repository.dart';
import '../../core/blocs/fetch_cubit.dart';
import '../../core/i18n/i18n.dart';
import '../../core/models/core_models.dart';
import '../../core/models/work_models.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hive_widgets.dart';
import '../../core/widgets/soft_card.dart';

typedef _ProjectsData = ({
  List<Project> active,
  List<Project> archived,
  Map<String, String> names,
});

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final FetchCubit<_ProjectsData> _cubit;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _cubit = FetchCubit<_ProjectsData>(() async {
      final repo = context.read<HivoraRepository>();
      final results = await Future.wait([
        repo.projects(),
        repo.projects(archived: true),
        repo.users(),
      ]);
      final active = results[0] as List<Project>;
      final archived = results[1] as List<Project>;
      final users = results[2] as List<DirectoryUser>;
      final names = {for (final u in users) u.id: u.displayName};
      return (active: active, archived: archived, names: names);
    })..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<FetchCubit<_ProjectsData>, FetchState<_ProjectsData>>(
        builder: (context, state) {
          final active = state.data?.active ?? const <Project>[];
          final archived = state.data?.archived ?? const <Project>[];
          final names = state.data?.names ?? const <String, String>{};
          final projects = _showArchived ? archived : active;
          return RefreshIndicator(
            onRefresh: _cubit.load,
            color: AppColors.accent,
            edgeOffset: context.topGutter,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    context.pageGutter,
                    24 + context.topGutter,
                    context.pageGutter,
                    16,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: PageHead(
                      title: context.t('projects.title'),
                      subtitle: context.t(
                        'projects.summary',
                        variables: {
                          'active': '${active.length}',
                          'archived': '${archived.length}',
                        },
                      ),
                      actions: [
                        PrimaryButton(
                          label: context.t('projects.new'),
                          onPressed: _showCreate,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    context.pageGutter,
                    0,
                    context.pageGutter,
                    16,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedControl(
                        selected: _showArchived ? 1 : 0,
                        onChanged: (i) =>
                            setState(() => _showArchived = i == 1),
                        items: [
                          SegmentItem(
                            label: context.t('projects.active'),
                            icon: LucideIcons.folderOpen,
                          ),
                          SegmentItem(
                            label: archived.isEmpty
                                ? context.t('projects.archived')
                                : '${context.t('projects.archived')} · ${archived.length}',
                            icon: LucideIcons.archive,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state.isLoading && projects.isEmpty)
                  const SliverFillRemaining(child: Center(child: HiveLoader()))
                else if (projects.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        _showArchived
                            ? context.t('projects.emptyArchived')
                            : context.t('projects.empty'),
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      context.pageGutter,
                      0,
                      context.pageGutter,
                      context.pageGutter + context.bottomGutter,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: context.gridColumns(minTileWidth: 300),
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        mainAxisExtent: 210,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ProjectCard(
                          project: projects[index],
                          names: names,
                          onSettings: () => _openSettings(projects[index]),
                        ),
                        childCount: projects.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreate() async {
    final repository = context.read<HivoraRepository>();
    final created = await WoltModalSheet.show<Project?>(
      context: context,
      pageListBuilder: (modalContext) => [
        WoltModalSheetPage(
          backgroundColor: AppColors.surface,
          hasTopBarLayer: false,
          child: RepositoryProvider.value(
            value: repository,
            child: const _CreateProjectBody(),
          ),
        ),
      ],
    );
    if (created != null) _cubit.load();
  }

  Future<void> _openSettings(Project project) async {
    await context.push('/projects/${project.id}/settings');
    if (mounted) _cubit.load();
  }
}

/// Parses a project's stored hex color (e.g. "#AEC6F4") to a Color, with a
/// stable hue fallback derived from the project key.
Color _projectColor(Project project) {
  final raw = project.color.replaceAll('#', '').trim();
  if (raw.length == 6) {
    final value = int.tryParse(raw, radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  return hiveHueColor(project.key);
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.names,
    required this.onSettings,
  });

  final Project project;
  final Map<String, String> names;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    // Mobile shows the compact gear in the corner; larger views show the
    // full-width "Settings" button in the footer instead.
    final compact = context.isCompact;
    final color = _projectColor(project);
    final glyphColor = project.archived
        ? HSLColor.fromColor(color).withSaturation(0.25).toColor()
        : color;
    final leadName = project.leadId != null ? names[project.leadId!] : null;
    final memberNames = project.memberIds
        .map((id) => names[id] ?? id)
        .toList(growable: false);
    final subtitle = leadName != null
        ? '${project.key} · ${context.t('projects.lead')} ${leadName.split(' ').first}'
        : project.key;

    final card = SoftCard(
      onTap: () => context.go('/issues?projectId=${project.id}'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.soft(glyphColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  project.key,
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: glyphColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leave room for the corner gear only when it's shown.
                    Padding(
                      padding: EdgeInsets.only(right: compact ? 26 : 0),
                      child: Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontMono,
                        fontSize: 11.5,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                value: '${project.memberIds.length}',
                label: context.t('projects.membersLabel'),
              ),
              const SizedBox(width: 20),
              _Stat(
                value: '${project.workflowStates.length}',
                label: context.t('projects.statesLabel'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          HiveProgress(value: _completion(project), color: glyphColor),
          const Spacer(),
          const SizedBox(height: 12),
          Row(
            children: [
              if (memberNames.isNotEmpty)
                Expanded(child: HiveAvatarStack(names: memberNames, size: 26))
              else
                const Spacer(),
              if (project.labels.isNotEmpty) ...[
                Icon(LucideIcons.tag, size: 14, color: AppColors.inkFaint),
                const SizedBox(width: 4),
                Text(
                  '${project.labels.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (!compact) _SettingsButton(onTap: onSettings),
            ],
          ),
        ],
      ),
    );

    final stacked = Stack(
      children: [
        card,
        if (compact)
          Positioned(top: 10, right: 10, child: _GearButton(onTap: onSettings)),
      ],
    );

    return project.archived ? Opacity(opacity: 0.82, child: stacked) : stacked;
  }

  // Resolved-state ratio gives a rough completion proxy when no counts exist.
  double _completion(Project project) {
    if (project.workflowStates.isEmpty) return 0.0;
    return (project.resolvedStates.length / project.workflowStates.length)
        .clamp(0.0, 1.0);
  }
}

/// Small gear affordance in the card corner that opens project settings.
class _GearButton extends StatelessWidget {
  const _GearButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(LucideIcons.settings, size: 15, color: AppColors.inkSoft),
        ),
      ),
    );
  }
}

/// Footer "Settings" ghost button on each project card.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.slidersHorizontal,
                size: 14,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Text(
                context.t('projects.settings'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTheme.fontBrand,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
      ],
    );
  }
}

class _CreateProjectBody extends StatefulWidget {
  const _CreateProjectBody();

  @override
  State<_CreateProjectBody> createState() => _CreateProjectBodyState();
}

class _CreateProjectBodyState extends State<_CreateProjectBody> {
  final _formKey = GlobalKey<FormState>();
  final _key = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('projects.new'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: context.t('projects.name'),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? context.t('errors.required')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _key,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: context.t('projects.key'),
                helperText: context.t('projects.keyHelp'),
              ),
              validator: (value) =>
                  RegExp(r'^[A-Za-z][A-Za-z0-9]{1,9}$').hasMatch(value ?? '')
                  ? null
                  : context.t('errors.invalidProjectKey'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.t('issues.description'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: HiveLoader(strokeWidth: 2, color: Colors.white),
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
      final project = await context.read<HivoraRepository>().createProject(
        key: _key.text.trim().toUpperCase(),
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(project);
    } on ApiFailure catch (failure) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
    }
  }
}
