import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/api/hinata_repository.dart';
import '../../core/i18n/i18n.dart';
import '../../core/models/account_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../sprint/modals/glass_modal.dart'
    show showGlassModal, GlassModalHeader, GlassField, glassInputDecoration;
import 'account_widgets.dart';

/// Edit display name / job title / locale → PATCH /me. Returns the saved [Me].
Future<Me?> showEditProfile(BuildContext context, HinataRepository repo, Me me) {
  return showGlassModal<Me>(
    context,
    width: 480,
    builder: (_) => _EditProfileModal(repo: repo, me: me),
  );
}

class _EditProfileModal extends StatefulWidget {
  const _EditProfileModal({required this.repo, required this.me});
  final HinataRepository repo;
  final Me me;

  @override
  State<_EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<_EditProfileModal> {
  late final _name = TextEditingController(text: widget.me.displayName);
  late final _title = TextEditingController(text: widget.me.title ?? '');
  late String _locale = widget.me.locale;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.repo.updateMyProfile(
        displayName: _name.text.trim(),
        title: _title.text.trim(),
        locale: _locale,
      );
      if (mounted) Navigator.of(context).maybePop(saved);
    } on ApiFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GlassModalHeader(
          icon: LucideIcons.userPen,
          title: 'Edit profile',
          subtitle: 'Your username is your permanent handle and can’t be changed.',
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassField(
                  label: 'Display name',
                  child: TextField(
                    controller: _name,
                    decoration: glassInputDecoration(hint: 'Your name'),
                  ),
                ),
                const SizedBox(height: 14),
                GlassField(
                  label: 'Username',
                  child: TextField(
                    enabled: false,
                    controller: TextEditingController(text: widget.me.username),
                    decoration: glassInputDecoration().copyWith(
                      prefixIcon: Icon(LucideIcons.atSign,
                          size: 16, color: AppColors.inkFaint),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GlassField(
                  label: 'Job title',
                  child: TextField(
                    controller: _title,
                    decoration: glassInputDecoration(hint: 'e.g. Maintainer'),
                  ),
                ),
                const SizedBox(height: 14),
                GlassField(
                  label: 'Language',
                  child: _LocaleDropdown(
                    value: _locale,
                    onChanged: (v) => setState(() => _locale = v),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AccountNote(
                    text: _error!,
                    icon: LucideIcons.triangleAlert,
                    tone: AccountNoteTone.danger,
                  ),
                ],
              ],
            ),
          ),
        ),
        _Footer(
          label: 'Save changes',
          icon: LucideIcons.check,
          busy: _busy,
          onConfirm: _save,
        ),
      ],
    );
  }
}

class _LocaleDropdown extends StatelessWidget {
  const _LocaleDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _names = {
    'en': 'English',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'ku': 'Kurdî',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppColors.hairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _names.containsKey(value) ? value : 'en',
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          items: [
            for (final e in _names.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

/// Change email → POST /me/email-change (double opt-in). Returns true if sent.
Future<bool?> showChangeEmail(
    BuildContext context, HinataRepository repo, Me me) {
  return showGlassModal<bool>(
    context,
    width: 460,
    builder: (_) => _ChangeEmailModal(repo: repo, me: me),
  );
}

class _ChangeEmailModal extends StatefulWidget {
  const _ChangeEmailModal({required this.repo, required this.me});
  final HinataRepository repo;
  final Me me;

  @override
  State<_ChangeEmailModal> createState() => _ChangeEmailModalState();
}

class _ChangeEmailModalState extends State<_ChangeEmailModal> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _email.text.trim();
    if (!value.contains('@') || value.length < 5) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.requestEmailChange(value);
      if (mounted) Navigator.of(context).maybePop(true);
    } on ApiFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GlassModalHeader(
          icon: LucideIcons.mail,
          title: 'Change email',
          subtitle: 'We’ll send a confirmation link to the new address. Your '
              'sign-in email only changes once you confirm it.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassField(
                label: 'Current email',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    border: Border.all(color: AppColors.hairline2),
                  ),
                  child: Text(widget.me.email,
                      style: TextStyle(color: AppColors.inkSoft)),
                ),
              ),
              const SizedBox(height: 14),
              GlassField(
                label: 'New email',
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: glassInputDecoration(hint: 'new@example.com'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                AccountNote(
                  text: _error!,
                  icon: LucideIcons.triangleAlert,
                  tone: AccountNoteTone.danger,
                ),
              ],
            ],
          ),
        ),
        _Footer(
          label: 'Send verification',
          icon: LucideIcons.sendHorizontal,
          busy: _busy,
          onConfirm: _send,
        ),
      ],
    );
  }
}

/// A generic danger / confirm dialog used for sign-out actions & data report.
Future<bool?> showConfirm(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
  required Future<void> Function() onConfirm,
}) {
  return showGlassModal<bool>(
    context,
    width: 420,
    builder: (_) => _ConfirmModal(
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      danger: danger,
      onConfirm: onConfirm,
    ),
  );
}

class _ConfirmModal extends StatefulWidget {
  const _ConfirmModal({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.danger,
    required this.onConfirm,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;
  final Future<void> Function() onConfirm;

  @override
  State<_ConfirmModal> createState() => _ConfirmModalState();
}

class _ConfirmModalState extends State<_ConfirmModal> {
  bool _busy = false;
  String? _error;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).maybePop(true);
    } on ApiFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassModalHeader(
          icon: widget.icon,
          title: widget.title,
          subtitle: widget.message,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: AccountNote(
              text: _error!,
              icon: LucideIcons.triangleAlert,
              tone: AccountNoteTone.danger,
            ),
          ),
        _Footer(
          label: widget.confirmLabel,
          icon: widget.danger ? LucideIcons.triangleAlert : LucideIcons.check,
          danger: widget.danger,
          busy: _busy,
          onConfirm: _run,
        ),
      ],
    );
  }
}

/// Type-DELETE-to-confirm account erasure (Art. 17). Returns true on success.
Future<bool?> showDeleteAccount(BuildContext context, HinataRepository repo) {
  return showGlassModal<bool>(
    context,
    width: 460,
    builder: (_) => _DeleteAccountModal(repo: repo),
  );
}

class _DeleteAccountModal extends StatefulWidget {
  const _DeleteAccountModal({required this.repo});
  final HinataRepository repo;

  @override
  State<_DeleteAccountModal> createState() => _DeleteAccountModalState();
}

class _DeleteAccountModalState extends State<_DeleteAccountModal> {
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool get _armed => _confirm.text.trim() == 'DELETE';

  Future<void> _delete() async {
    if (!_armed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.deleteMyAccount();
      if (mounted) Navigator.of(context).maybePop(true);
    } on ApiFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GlassModalHeader(
          icon: LucideIcons.trash2,
          title: 'Delete my account',
          subtitle: 'This permanently erases your profile, credentials and sessions. '
              'Your authored issues & comments are anonymised. This cannot be undone.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassField(
                label: 'Type DELETE to confirm',
                child: TextField(
                  controller: _confirm,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                  ],
                  textCapitalization: TextCapitalization.characters,
                  decoration: glassInputDecoration(hint: 'DELETE'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                AccountNote(
                  text: _error!,
                  icon: LucideIcons.triangleAlert,
                  tone: AccountNoteTone.danger,
                ),
              ],
            ],
          ),
        ),
        _Footer(
          label: 'Delete account',
          icon: LucideIcons.trash2,
          danger: true,
          busy: _busy,
          onConfirm: _armed ? _delete : null,
        ),
      ],
    );
  }
}

/// Shared modal footer (Cancel + a primary/danger confirm). A null [onConfirm]
/// renders the button disabled (used for the type-to-confirm gate).
class _Footer extends StatelessWidget {
  const _Footer({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onConfirm,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onConfirm;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.hairline.withValues(alpha: 0.6)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).maybePop(),
              child: Text(context.t('common.cancel')),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: busy ? null : onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: danger ? AppColors.danger : AppColors.navy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.hairline,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                ),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(icon, size: 15),
              label: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
