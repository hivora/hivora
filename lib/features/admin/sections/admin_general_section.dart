import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../admin_form_helpers.dart';

/// General organization settings: name, logo, timezone, default language.
class AdminGeneralSection extends StatefulWidget {
  const AdminGeneralSection({super.key, required this.settings});

  final Map<String, dynamic> settings;

  @override
  State<AdminGeneralSection> createState() => _AdminGeneralSectionState();
}

class _AdminGeneralSectionState extends State<AdminGeneralSection> {
  Map<String, dynamic> get _general =>
      (widget.settings['general'] ??= <String, dynamic>{})
          as Map<String, dynamic>;

  static const _timezones = [
    'Europe/Berlin',
    'Europe/London',
    'Europe/Paris',
    'Europe/Madrid',
    'Europe/Amsterdam',
    'UTC',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'Asia/Tokyo',
    'Asia/Shanghai',
    'Asia/Kolkata',
    'Australia/Sydney',
  ];

  static const _locales = [
    ('de', 'Deutsch (Deutschland)'),
    ('en', 'English (United Kingdom)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionCard(
          icon: Icons.business_rounded,
          title: context.t('admin.general'),
          subtitle: context.t('admin.generalHint'),
          children: [
            AdminField(
              label: context.t('admin.orgName'),
              initialValue:
                  (widget.settings['organizationName'] as String?) ?? '',
              onChanged: (v) => widget.settings['organizationName'] = v,
            ),
            AdminField(
              label: context.t('admin.logoUrl'),
              initialValue: (_general['logoUrl'] as String?) ?? '',
              onChanged: (v) => _general['logoUrl'] = v,
              hint: 'https://example.com/logo.png',
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminSectionCard(
          icon: Icons.language_rounded,
          title: context.t('admin.localization'),
          subtitle: context.t('admin.localizationHint'),
          children: [
            DropdownButtonFormField<String>(
              initialValue: (_general['timezone'] as String?) ??
                  'Europe/Berlin',
              decoration: InputDecoration(
                  labelText: context.t('admin.timezone')),
              items: _timezones
                  .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _general['timezone'] = v);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue:
                  (_general['defaultLocale'] as String?) ?? 'de',
              decoration: InputDecoration(
                  labelText: context.t('admin.defaultLanguage')),
              items: _locales
                  .map((l) => DropdownMenuItem(
                      value: l.$1, child: Text(l.$2)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _general['defaultLocale'] = v);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
