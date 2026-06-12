import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../admin_form_helpers.dart';

/// Push notification settings (Firebase Cloud Messaging).
class AdminNotificationsSection extends StatefulWidget {
  const AdminNotificationsSection({super.key, required this.settings});

  final Map<String, dynamic> settings;

  @override
  State<AdminNotificationsSection> createState() =>
      _AdminNotificationsSectionState();
}

class _AdminNotificationsSectionState
    extends State<AdminNotificationsSection> {
  Map<String, dynamic> get _push =>
      (widget.settings['push'] ??= <String, dynamic>{})
          as Map<String, dynamic>;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionCard(
          icon: Icons.notifications_active_rounded,
          title: context.t('admin.pushNotifications'),
          subtitle: context.t('admin.pushHint'),
          children: [
            AdminToggle(
              label: 'Firebase Cloud Messaging (FCM)',
              subtitle: context.t('admin.fcmSubtitle'),
              value: _push['enabled'] == true,
              onChanged: (v) => setState(() => _push['enabled'] = v),
            ),
            if (_push['enabled'] == true) ...[
              const SizedBox(height: 12),
              AdminField(
                label: context.t('admin.fcmProjectId'),
                initialValue:
                    (_push['fcmProjectId'] as String?) ?? '',
                onChanged: (v) => _push['fcmProjectId'] = v,
                hint: 'my-firebase-project',
              ),
              AdminField(
                label: context.t('admin.fcmServiceAccount'),
                initialValue: '',
                isSecret: true,
                onChanged: (v) => _push['fcmServiceAccountJson'] = v,
                hint: '{"type": "service_account", ...}',
              ),
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: Color(0xFFF57F17)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t('admin.fcmDocHint'),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF7B4F00)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
