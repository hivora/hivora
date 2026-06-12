import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/hivora_repository.dart';
import '../../core/i18n/i18n.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'admin_sso_section.dart';
import 'sections/admin_email_section.dart';
import 'sections/admin_general_section.dart';
import 'sections/admin_notifications_section.dart';
import 'sections/admin_security_section.dart';

// ─────────────────────────── Admin Panel Shell ────────────────────────────

enum _AdminSection {
  general,
  authentication,
  email,
  notifications,
  security,
  auditLog,
  users,
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  _AdminSection _section = _AdminSection.general;

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
      _settings = await context.read<HivoraRepository>().adminSettings();
      setState(() => _loading = false);
    } on ApiFailure catch (failure) {
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _saving = true);
    try {
      _settings =
          await context.read<HivoraRepository>().updateAdminSettings(_settings!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('admin.saved'))));
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.navy));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.inkFaint),
            const SizedBox(height: 12),
            Text(context.t(_error!),
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _load, child: Text(context.t('common.retry'))),
          ],
        ),
      );
    }

    return ResponsiveBuilder(
      builder: (context, size) => size == LayoutSize.compact
          ? _MobileAdminShell(
              section: _section,
              settings: _settings!,
              saving: _saving,
              onSectionChanged: (s) => setState(() => _section = s),
              onSave: _save,
            )
          : _WideAdminShell(
              section: _section,
              settings: _settings!,
              saving: _saving,
              onSectionChanged: (s) => setState(() => _section = s),
              onSave: _save,
            ),
    );
  }
}

// ─────────────────────────── Wide layout (≥ medium) ──────────────────────

class _WideAdminShell extends StatelessWidget {
  const _WideAdminShell({
    required this.section,
    required this.settings,
    required this.saving,
    required this.onSectionChanged,
    required this.onSave,
  });

  final _AdminSection section;
  final Map<String, dynamic> settings;
  final bool saving;
  final ValueChanged<_AdminSection> onSectionChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Admin nav rail
        Container(
          width: 220,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(right: BorderSide(color: AppColors.hairline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('admin.title'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.t('admin.subtitle'),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.hairline),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  children: [
                    _NavGroup(label: context.t('admin.navGeneral')),
                    _NavItem(
                      icon: Icons.business_rounded,
                      label: context.t('admin.general'),
                      section: _AdminSection.general,
                      current: section,
                      onTap: onSectionChanged,
                    ),
                    _NavItem(
                      icon: Icons.shield_rounded,
                      label: context.t('admin.security'),
                      section: _AdminSection.security,
                      current: section,
                      onTap: onSectionChanged,
                    ),
                    const SizedBox(height: 8),
                    _NavGroup(label: context.t('admin.navIntegrations')),
                    _NavItem(
                      icon: Icons.lock_rounded,
                      label: context.t('admin.authentication'),
                      section: _AdminSection.authentication,
                      current: section,
                      onTap: onSectionChanged,
                    ),
                    _NavItem(
                      icon: Icons.mail_rounded,
                      label: context.t('admin.email'),
                      section: _AdminSection.email,
                      current: section,
                      onTap: onSectionChanged,
                    ),
                    _NavItem(
                      icon: Icons.notifications_rounded,
                      label: context.t('admin.pushNotifications'),
                      section: _AdminSection.notifications,
                      current: section,
                      onTap: onSectionChanged,
                    ),
                    const SizedBox(height: 8),
                    _NavGroup(label: context.t('admin.navSystem')),
                    _NavItem(
                      icon: Icons.history_rounded,
                      label: context.t('admin.auditLog'),
                      section: _AdminSection.auditLog,
                      current: section,
                      onTap: onSectionChanged,
                    ),
                    _NavItem(
                      icon: Icons.people_rounded,
                      label: context.t('admin.users'),
                      section: _AdminSection.users,
                      current: section,
                      onTap: onSectionChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _SectionContent(
            section: section,
            settings: settings,
            saving: saving,
            onSave: onSave,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Mobile layout ───────────────────────────────

class _MobileAdminShell extends StatelessWidget {
  const _MobileAdminShell({
    required this.section,
    required this.settings,
    required this.saving,
    required this.onSectionChanged,
    required this.onSave,
  });

  final _AdminSection section;
  final Map<String, dynamic> settings;
  final bool saving;
  final ValueChanged<_AdminSection> onSectionChanged;
  final VoidCallback onSave;

  static const _sections = [
    (Icons.business_rounded, 'admin.general', _AdminSection.general),
    (Icons.shield_rounded, 'admin.security', _AdminSection.security),
    (Icons.lock_rounded, 'admin.authentication', _AdminSection.authentication),
    (Icons.mail_rounded, 'admin.email', _AdminSection.email),
    (Icons.notifications_rounded, 'admin.pushNotifications', _AdminSection.notifications),
    (Icons.history_rounded, 'admin.auditLog', _AdminSection.auditLog),
    (Icons.people_rounded, 'admin.users', _AdminSection.users),
  ];

  @override
  Widget build(BuildContext context) {
    // On mobile: show a section list; navigating into one shows content + back.
    // We use a local "selected" index approach inside this widget.
    // Since this widget rebuilds on section changes from parent, the back action
    // resets section to a sentinel by calling onSectionChanged with a reset.
    // Instead, use a simple conditional: if section is still the default "general"
    // value AND the user hasn't tapped in yet, show the list. Otherwise content.
    // We track this with the parent's section state.

    return Column(
      children: [
        // Top bar
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              Text(
                context.t('admin.title'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.ink),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final (icon, labelKey, sec) in _sections)
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: section == sec
                          ? AppColors.accentSoft
                          : AppColors.canvas2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon,
                        size: 18,
                        color: section == sec
                            ? AppColors.accentStrong
                            : AppColors.inkSoft),
                  ),
                  title: Text(
                    context.t(labelKey),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.inkFaint),
                  onTap: () {
                    if (sec == _AdminSection.users) {
                      context.push('/admin/users');
                    } else {
                      onSectionChanged(sec);
                      // Push a temporary "content" route — for simplicity we
                      // show a bottom sheet on mobile for non-users sections
                      _showMobileSection(context, sec);
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMobileSection(BuildContext context, _AdminSection sec) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: _SectionContent(
            section: sec,
            settings: settings,
            saving: saving,
            onSave: onSave,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Section content router ──────────────────────

class _SectionContent extends StatelessWidget {
  const _SectionContent({
    required this.section,
    required this.settings,
    required this.saving,
    required this.onSave,
  });

  final _AdminSection section;
  final Map<String, dynamic> settings;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    if (section == _AdminSection.users) {
      // Navigate to the dedicated users page
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.push('/admin/users'),
      );
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Content header
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _sectionTitle(context, section),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.ink),
                ),
              ),
              if (section != _AdminSection.auditLog) ...[
                if (saving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.navy),
                  )
                else
                  FilledButton.icon(
                    onPressed: onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: Text(context.t('common.save')),
                  ),
              ],
            ],
          ),
        ),
        // Scrollable section body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _sectionBody(section),
          ),
        ),
      ],
    );
  }

  String _sectionTitle(BuildContext context, _AdminSection sec) => switch (sec) {
        _AdminSection.general => context.t('admin.general'),
        _AdminSection.authentication => context.t('admin.authentication'),
        _AdminSection.email => context.t('admin.email'),
        _AdminSection.notifications => context.t('admin.pushNotifications'),
        _AdminSection.security => context.t('admin.security'),
        _AdminSection.auditLog => context.t('admin.auditLog'),
        _AdminSection.users => context.t('admin.users'),
      };

  Widget _sectionBody(_AdminSection sec) => switch (sec) {
        _AdminSection.general => AdminGeneralSection(settings: settings),
        _AdminSection.authentication => AdminSsoSection(settings: settings),
        _AdminSection.email => AdminEmailSection(settings: settings),
        _AdminSection.notifications =>
          AdminNotificationsSection(settings: settings),
        _AdminSection.security => AdminSecuritySection(settings: settings),
        _AdminSection.auditLog => const _AuditLogPlaceholder(),
        _AdminSection.users => const SizedBox.shrink(),
      };
}

// ─────────────────────────── Nav helpers ─────────────────────────────────

class _NavGroup extends StatelessWidget {
  const _NavGroup({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTheme.fontMono,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.inkFaint,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.section,
    required this.current,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _AdminSection section;
  final _AdminSection current;
  final ValueChanged<_AdminSection> onTap;

  @override
  Widget build(BuildContext context) {
    final active = section == current;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          if (section == _AdminSection.users) {
            context.push('/admin/users');
          } else {
            onTap(section);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: active
              ? BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: active ? AppColors.accentStrong : AppColors.inkSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? AppColors.accentStrong : AppColors.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (section == _AdminSection.users)
                const Icon(Icons.open_in_new_rounded,
                    size: 13, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Audit log placeholder ───────────────────────

class _AuditLogPlaceholder extends StatelessWidget {
  const _AuditLogPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 60),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.canvas2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.history_rounded,
                size: 36, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          Text(
            context.t('admin.auditLogSoon'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('admin.auditLogHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.inkSoft, height: 1.5),
          ),
        ],
      ),
    );
  }
}
