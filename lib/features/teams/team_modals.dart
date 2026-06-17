import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_client.dart';
import '../../core/api/hivora_repository.dart';
import '../../core/i18n/i18n.dart';
import '../../core/models/team_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'team_modal_kit.dart';
import 'team_widgets.dart';

export 'team_member_modals.dart';
export 'team_project_modal.dart';

/// Create-team modal. Returns the created [Team] (so the caller can open it).
Future<Team?> showCreateTeamModal(BuildContext context) {
  final repo = context.read<HivoraRepository>();
  return showTeamModal<Team>(context, _TeamFormBody(repo: repo), width: 580);
}

/// Edit-team modal. Returns true if the team was saved.
Future<bool?> showEditTeamModal(BuildContext context, Team team) {
  final repo = context.read<HivoraRepository>();
  return showTeamModal<bool>(
    context,
    _TeamFormBody(repo: repo, existing: team),
    width: 580,
  );
}

/// Delete-team modal (type-to-confirm). Returns true if deleted.
Future<bool?> showDeleteTeamModal(BuildContext context, Team team) {
  final repo = context.read<HivoraRepository>();
  return showTeamModal<bool>(
    context,
    _DeleteTeamBody(repo: repo, team: team),
    width: 460,
  );
}

class _TeamFormBody extends StatefulWidget {
  const _TeamFormBody({required this.repo, this.existing});

  final HivoraRepository repo;
  final Team? existing;

  @override
  State<_TeamFormBody> createState() => _TeamFormBodyState();
}

class _TeamFormBodyState extends State<_TeamFormBody> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _key = TextEditingController(
    text: widget.existing?.key ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late int _hue = widget.existing?.colorHue ?? 70;
  late String _icon = widget.existing?.icon ?? 'hexagon';
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    _desc.dispose();
    super.dispose();
  }

  String get _effectiveKey {
    final typed = _key.text.trim().toUpperCase();
    if (typed.isNotEmpty) return typed;
    final from = _name.text.trim();
    return from.isEmpty
        ? ''
        : from.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.t('errors.required'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.repo.updateTeam(widget.existing!.id, {
          'name': name,
          'key': _effectiveKey.isEmpty ? widget.existing!.key : _effectiveKey,
          'description': _desc.text.trim(),
          'colorHue': _hue,
          'icon': _icon,
        });
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final created = await widget.repo.createTeam(
          name: name,
          key: _effectiveKey.isEmpty
              ? name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase()
              : _effectiveKey,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          colorHue: _hue,
          icon: _icon,
        );
        if (mounted) Navigator.of(context).pop(created);
      }
    } on ApiFailure catch (failure) {
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = teamHueColor(_hue);
    return ModalShell(
      icon: _isEdit ? LucideIcons.slidersHorizontal : LucideIcons.usersRound,
      title: context.t(_isEdit ? 'teams.editTitle' : 'teams.createTitle'),
      subtitle: context.t(
        _isEdit ? 'teams.editSubtitle' : 'teams.createSubtitle',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Identity row: live glyph + name + key.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.soft(color),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(teamIcon(_icon), size: 26, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel(context.t('teams.name')),
                    TextField(
                      controller: _name,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: teamFieldDecoration(
                        context,
                        hint: context.t('teams.namePlaceholder'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel(context.t('teams.key')),
                    TextField(
                      controller: _key,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 5,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      style: const TextStyle(fontFamily: AppTheme.fontMono),
                      decoration: teamFieldDecoration(context, hint: 'CORE'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FieldLabel(context.t('teams.description'), optional: true),
          TextField(
            controller: _desc,
            minLines: 2,
            maxLines: 4,
            decoration: teamFieldDecoration(
              context,
              hint: context.t('teams.descriptionPlaceholder'),
            ),
          ),
          const SizedBox(height: 18),
          FieldLabel(context.t('teams.colorLabel')),
          ColorPicker(hue: _hue, onChanged: (h) => setState(() => _hue = h)),
          const SizedBox(height: 18),
          FieldLabel(context.t('teams.iconLabel')),
          IconPicker(
            selected: _icon,
            onChanged: (i) => setState(() => _icon = i),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
            ),
          ],
        ],
      ),
      footer: ModalFooter(
        primaryLabel: context.t(_isEdit ? 'common.save' : 'teams.createCta'),
        primaryIcon: _isEdit ? LucideIcons.check : LucideIcons.check,
        busy: _busy,
        onPrimary: _name.text.trim().isEmpty ? null : _submit,
      ),
    );
  }
}

class _DeleteTeamBody extends StatefulWidget {
  const _DeleteTeamBody({required this.repo, required this.team});

  final HivoraRepository repo;
  final Team team;

  @override
  State<_DeleteTeamBody> createState() => _DeleteTeamBodyState();
}

class _DeleteTeamBodyState extends State<_DeleteTeamBody> {
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _ok =>
      _confirm.text.trim().toLowerCase() ==
      widget.team.name.trim().toLowerCase();

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.deleteTeam(widget.team.id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (failure) {
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberCount = widget.team.members.length;
    return ModalShell(
      icon: LucideIcons.trash2,
      iconColor: AppColors.danger,
      iconBg: AppColors.dangerSoft,
      title: context.t(
        'teams.deleteTitle',
        variables: {'name': widget.team.name},
      ),
      subtitle: context.t('teams.deleteSubtitle'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: 16, color: AppColors.accentStrong),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t(
                      'teams.deleteWarn',
                      variables: {'count': '$memberCount'},
                      count: memberCount,
                    ),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FieldLabel(
            context.t(
              'teams.deleteConfirmLabel',
              variables: {'name': widget.team.name},
            ),
          ),
          TextField(
            controller: _confirm,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: teamFieldDecoration(context, hint: widget.team.name),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
            ),
          ],
        ],
      ),
      footer: ModalFooter(
        primaryLabel: context.t('teams.deleteCta'),
        primaryIcon: LucideIcons.trash2,
        danger: true,
        busy: _busy,
        onPrimary: _ok ? _delete : null,
      ),
    );
  }
}
