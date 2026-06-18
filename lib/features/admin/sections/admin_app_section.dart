import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/hive_widgets.dart';
import '../admin_form_helpers.dart';

/// App/client settings served to the apps via /api/v1/meta: the minimum
/// required app version, the privacy policy URL and optional feature flags.
class AdminAppSection extends StatefulWidget {
  const AdminAppSection({super.key, required this.settings});

  final Map<String, dynamic> settings;

  @override
  State<AdminAppSection> createState() => _AdminAppSectionState();
}

class _AdminAppSectionState extends State<AdminAppSection> {
  Map<String, dynamic> get _app =>
      (widget.settings['app'] ??= <String, dynamic>{})
          as Map<String, dynamic>;

  Map<String, dynamic> get _flags =>
      (_app['featureFlags'] ??= <String, dynamic>{})
          as Map<String, dynamic>;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionCard(
          icon: LucideIcons.smartphone,
          title: context.t('admin.appReleases'),
          subtitle: context.t('admin.appReleasesHint'),
          children: [
            AdminField(
              label: context.t('admin.minVersion'),
              initialValue: (_app['minVersion'] as String?) ?? '',
              onChanged: (v) => _app['minVersion'] = v,
              hint: '1.0.0',
            ),
            AdminField(
              label: context.t('admin.privacyPolicyUrl'),
              initialValue: (_app['privacyPolicyUrl'] as String?) ?? '',
              onChanged: (v) => _app['privacyPolicyUrl'] = v,
              hint: 'https://example.com/privacy',
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminSectionCard(
          icon: LucideIcons.flag,
          title: context.t('admin.featureFlags'),
          subtitle: context.t('admin.featureFlagsHint'),
          children: [
            _FeatureFlagEditor(
              flags: _flags,
              onChanged: () => setState(() {}),
            ),
          ],
        ),
      ],
    );
  }
}

/// Add / toggle / remove arbitrary `name → enabled` feature flags.
class _FeatureFlagEditor extends StatefulWidget {
  const _FeatureFlagEditor({required this.flags, required this.onChanged});

  final Map<String, dynamic> flags;
  final VoidCallback onChanged;

  @override
  State<_FeatureFlagEditor> createState() => _FeatureFlagEditorState();
}

class _FeatureFlagEditorState extends State<_FeatureFlagEditor> {
  final _newFlag = TextEditingController();

  @override
  void dispose() {
    _newFlag.dispose();
    super.dispose();
  }

  void _add() {
    final name = _newFlag.text.trim();
    if (name.isEmpty || widget.flags.containsKey(name)) return;
    setState(() {
      widget.flags[name] = true;
      _newFlag.clear();
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.flags.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.t('admin.featureFlagsEmpty'),
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink),
                  ),
                ),
                HiveSwitch(
                  value: entry.value == true,
                  onChanged: (v) {
                    setState(() => widget.flags[entry.key] = v);
                    widget.onChanged();
                  },
                ),
                IconButton(
                  icon: Icon(LucideIcons.trash2,
                      size: 16, color: AppColors.inkFaint),
                  tooltip: context.t('common.delete'),
                  onPressed: () {
                    setState(() => widget.flags.remove(entry.key));
                    widget.onChanged();
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newFlag,
                decoration: InputDecoration(
                  labelText: context.t('admin.featureFlagName'),
                  isDense: true,
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(context.t('common.add')),
            ),
          ],
        ),
      ],
    );
  }
}
