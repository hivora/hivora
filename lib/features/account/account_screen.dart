import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/hinata_repository.dart';
import '../../core/blocs/app_config_bloc.dart';
import '../../core/blocs/auth_bloc.dart';
import '../../core/blocs/locale_cubit.dart';
import '../../core/blocs/theme_cubit.dart';
import '../../core/i18n/i18n.dart';
import '../../core/models/account_models.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/hex_mark.dart';
import '../../core/widgets/hive_loader.dart';
import '../../core/widgets/honeycomb_background.dart';
import 'account_modals.dart';
import 'account_widgets.dart';
import 'twofa_modals.dart';

/// The self-service `/me` account surface — profile, email & security, 2FA,
/// device sessions, notification preferences, access overview, appearance and
/// the GDPR data/danger zone. Replaces the former lightweight settings screen.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

/// The stable notification taxonomy — ids mirror the server's NOTIF_EVENTS.
const _notifEvents = <({String id, IconData icon, String label, String desc, bool locked})>[
  (id: 'mentions', icon: LucideIcons.atSign, label: 'Mentions & replies', desc: 'Someone @mentions you or replies to your comment', locked: false),
  (id: 'assigned', icon: LucideIcons.userCheck, label: 'Issue assigned to you', desc: 'You are added as the assignee of an issue', locked: false),
  (id: 'comments', icon: LucideIcons.messageSquare, label: 'Comments on my issues', desc: 'New comments on issues you created or watch', locked: false),
  (id: 'status', icon: LucideIcons.refreshCw, label: 'Status changes', desc: 'Watched issues move across the board', locked: false),
  (id: 'sprint', icon: LucideIcons.goal, label: 'Sprints & deadlines', desc: 'Sprint start / end and approaching due dates', locked: false),
  (id: 'invites', icon: LucideIcons.usersRound, label: 'Team & project invites', desc: 'You are invited to a team or project', locked: false),
  (id: 'digest', icon: LucideIcons.newspaper, label: 'Weekly digest', desc: 'A Monday summary of your workspace activity', locked: false),
  (id: 'security', icon: LucideIcons.shieldCheck, label: 'Security alerts', desc: 'New sign-ins, password & email changes', locked: true),
];

class _AccountScreenState extends State<AccountScreen> {
  HinataRepository get _repo => context.read<HinataRepository>();

  Me? _me;
  List<DeviceSession> _sessions = const [];
  List<AccessTeam> _teams = const [];
  List<AccessProject> _projects = const [];
  NotifPrefs? _prefs;
  bool _loading = true;

  Timer? _prefsDebounce;
  bool _accessTeams = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _prefsDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.meAccount(),
        _repo.sessions(),
        _repo.myTeams(),
        _repo.myProjects(),
      ]);
      if (!mounted) return;
      setState(() {
        _me = results[0] as Me;
        _sessions = results[1] as List<DeviceSession>;
        _teams = results[2] as List<AccessTeam>;
        _projects = results[3] as List<AccessProject>;
        _prefs = (results[0] as Me).notificationPreferences;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- mutations ------------------------------------------------------------

  Future<void> _editProfile() async {
    final saved = await showEditProfile(context, _repo, _me!);
    if (saved != null && mounted) {
      setState(() => _me = saved);
      // Keep the app shell (avatar / name) in sync with the edited profile.
      context.read<AuthBloc>().add(const AuthChecked());
      _toast('Profile updated');
    }
  }

  Future<void> _changeEmail() async {
    final sent = await showChangeEmail(context, _repo, _me!);
    if (sent == true && mounted) {
      _toast('Verification link sent to your new address');
      _load();
    }
  }

  Future<void> _resetPassword() async {
    final ok = await showConfirm(
      context,
      icon: LucideIcons.keyRound,
      title: 'Reset password',
      message: 'We’ll email a one-time link to set a new password. '
          'It expires in 30 minutes.',
      confirmLabel: 'Email reset link',
      onConfirm: () => _repo.sendPasswordReset(),
    );
    if (ok == true) _toast('Password reset link sent');
  }

  Future<void> _enable2fa() async {
    final enabled = await show2faWizard(context, _repo);
    if (enabled == true) {
      _toast('Two-factor authentication enabled');
      _load();
    }
  }

  Future<void> _disable2fa() async {
    final disabled = await show2faDisable(context, _repo);
    if (disabled == true) {
      _toast('Two-factor authentication disabled');
      _load();
    }
  }

  Future<void> _revokeSession(DeviceSession s) async {
    final ok = await showConfirm(
      context,
      icon: LucideIcons.logOut,
      title: 'Sign out device',
      message: 'Sign out ${s.client ?? s.os ?? 'this device'}? It will need to '
          'sign in again.',
      confirmLabel: 'Sign out',
      danger: true,
      onConfirm: () => _repo.revokeSession(s.id),
    );
    if (ok == true) {
      _toast('Device signed out');
      _load();
    }
  }

  Future<void> _revokeOthers() async {
    final ok = await showConfirm(
      context,
      icon: LucideIcons.logOut,
      title: 'Sign out all other devices',
      message: 'Every device except this one will be signed out immediately.',
      confirmLabel: 'Sign out all others',
      danger: true,
      onConfirm: () => _repo.revokeOtherSessions(),
    );
    if (ok == true) {
      _toast('Signed out of all other devices');
      _load();
    }
  }

  Future<void> _dataReport() async {
    final ok = await showConfirm(
      context,
      icon: LucideIcons.download,
      title: 'Request my data',
      message: 'We’ll compile an export of your data and email you a secure '
          'download link, generated within 24 hours (GDPR Art. 15).',
      confirmLabel: 'Request report',
      onConfirm: () => _repo.requestDataReport(),
    );
    if (ok == true) _toast('Data report requested — check your email');
  }

  Future<void> _deleteAccount() async {
    final done = await showDeleteAccount(context, _repo);
    if (done == true && mounted) {
      context.read<AuthBloc>().add(const LogoutRequested());
    }
  }

  void _onTogglePrefs(NotifPrefs next) {
    setState(() => _prefs = next);
    _prefsDebounce?.cancel();
    _prefsDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final saved = await _repo.saveNotificationPrefs(next);
        if (mounted) setState(() => _prefs = saved);
      } catch (_) {
        if (mounted) _toast('Could not save notification preferences');
      }
    });
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading && _me == null) {
      return const Center(child: HiveLoader());
    }
    if (_me == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t('errors.unexpected'),
                  style: TextStyle(color: AppColors.inkSoft)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(context.t('common.retry'))),
            ],
          ),
        ),
      );
    }

    final expanded = context.isExpanded;
    final left = <Widget>[
      _securitySection(),
      const SizedBox(height: 16),
      _sessionsSection(),
      const SizedBox(height: 16),
      _notificationsSection(),
    ];
    final right = <Widget>[
      _accessSection(),
      const SizedBox(height: 16),
      _appearanceSection(),
      const SizedBox(height: 16),
      _dataSection(),
      const SizedBox(height: 16),
      _dangerSection(),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: context.pagePadding,
        children: [
          Text('My account',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: AppTheme.fontBrand,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  )),
          const SizedBox(height: 14),
          _profileHero(),
          const SizedBox(height: 16),
          if (expanded)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1618, child: Column(children: left)),
                const SizedBox(width: 16),
                Expanded(flex: 1000, child: Column(children: right)),
              ],
            )
          else
            Column(children: [...left, const SizedBox(height: 16), ...right]),
        ],
      ),
    );
  }

  // --- profile hero ---------------------------------------------------------

  Widget _profileHero() {
    final me = _me!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.rail, AppColors.navy, AppColors.accentStrong],
                  stops: [0, 0.55, 1.4],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: HoneycombBackground(opacity: 0.06, color: Colors.white),
          ),
          Positioned(
            right: -10,
            top: -10,
            child: Opacity(
              opacity: 0.10,
              child: HexMark(size: 120, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ResponsiveBuilder(
              builder: (context, size) {
                final column = size == LayoutSize.compact;
                final identity = _heroIdentity(me, onDark: true);
                final actions = _heroActions();
                return Flex(
                  direction: column ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment:
                      column ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: column ? 0 : 1, child: identity),
                    SizedBox(width: column ? 0 : 16, height: column ? 16 : 0),
                    actions,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroIdentity(Me me, {required bool onDark}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
          ),
          child: AppAvatar(name: me.displayName, radius: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                me.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontBrand,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '@${me.username} · ${me.title ?? me.origin.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final role in me.roles)
                    AccountPill(
                      label: role[0] + role.substring(1).toLowerCase(),
                      color: Colors.white,
                      background: Colors.white.withValues(alpha: 0.18),
                    ),
                  if (me.createdAt != null)
                    AccountPill(
                      label: 'Member since ${_monthYear(me.createdAt!)}',
                      icon: LucideIcons.calendar,
                      color: Colors.white,
                      background: Colors.white.withValues(alpha: 0.12),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: _editProfile,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.navy,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            ),
          ),
          icon: const Icon(LucideIcons.pencil, size: 15),
          label: const Text('Edit profile'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () =>
              context.read<AuthBloc>().add(const LogoutRequested()),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.85),
          ),
          icon: const Icon(LucideIcons.logOut, size: 15),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  // --- email & security -----------------------------------------------------

  Widget _securitySection() {
    final me = _me!;
    final sso = me.origin.isSso;
    return AccountSection(
      icon: LucideIcons.shieldCheck,
      title: 'Email & security',
      subtitle: 'Sign-in address, password and two-factor authentication.',
      children: [
        SettingRow(
          label: 'Email',
          description: me.email,
          stack: context.isCompact,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AccountPill(
                label: me.emailVerified ? 'Verified' : 'Unverified',
                icon: me.emailVerified ? LucideIcons.circleCheck : LucideIcons.info,
                color: me.emailVerified ? AppColors.success : AppColors.warning,
              ),
              if (!sso) ...[
                const SizedBox(width: 8),
                AccountActionButton(
                  label: 'Change',
                  icon: LucideIcons.pencil,
                  onPressed: _changeEmail,
                ),
              ],
            ],
          ),
        ),
        if (me.pendingEmail != null) ...[
          const SizedBox(height: 4),
          AccountNote(
            text: 'Pending confirmation for ${me.pendingEmail}. '
                'Your current email stays active until you confirm the link.',
          ),
          const SizedBox(height: 4),
        ],
        if (sso)
          AccountNote(
            text: 'Email and password are managed by your identity provider '
                '(${me.origin.label}).',
            icon: LucideIcons.lock,
            tone: AccountNoteTone.info,
          ),
        if (!sso) ...[
          Divider(height: 1, color: AppColors.hairline2),
          SettingRow(
            label: 'Password',
            description: me.passwordChangedAt != null
                ? 'Last changed ${_monthYear(me.passwordChangedAt!)}'
                : 'Reset via a one-time email link',
            stack: context.isCompact,
            trailing: AccountActionButton(
              label: 'Reset',
              icon: LucideIcons.keyRound,
              onPressed: _resetPassword,
            ),
          ),
        ],
        Divider(height: 1, color: AppColors.hairline2),
        SettingRow(
          label: 'Two-factor authentication',
          description: me.twoFactor.enabled
              ? 'On · ${me.twoFactor.recoveryRemaining} recovery codes left'
              : 'Add an authenticator app for a second sign-in step',
          stack: context.isCompact,
          trailing: me.twoFactor.enabled
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AccountActionButton(
                      label: 'Codes',
                      icon: LucideIcons.keyRound,
                      onPressed: () => show2faManage(context, _repo).then((_) => _load()),
                    ),
                    const SizedBox(width: 8),
                    AccountActionButton(
                      label: 'Disable',
                      danger: true,
                      onPressed: _disable2fa,
                    ),
                  ],
                )
              : FilledButton.icon(
                  onPressed: _enable2fa,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    ),
                  ),
                  icon: const Icon(LucideIcons.shieldCheck, size: 15),
                  label: const Text('Enable'),
                ),
        ),
      ],
    );
  }

  // --- sessions -------------------------------------------------------------

  Widget _sessionsSection() {
    final others = _sessions.where((s) => !s.current).toList();
    return AccountSection(
      icon: LucideIcons.monitorSmartphone,
      title: 'Active sessions',
      subtitle: '${_sessions.length} signed-in ${_sessions.length == 1 ? 'device' : 'devices'}.',
      trailing: others.isEmpty
          ? null
          : AccountActionButton(
              label: 'Sign out others',
              icon: LucideIcons.logOut,
              danger: true,
              onPressed: _revokeOthers,
            ),
      children: [
        for (var i = 0; i < _sessions.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppColors.hairline2),
          _sessionRow(_sessions[i]),
        ],
      ],
    );
  }

  Widget _sessionRow(DeviceSession s) {
    final icon = switch (s.kind) {
      'phone' => LucideIcons.smartphone,
      'tablet' => LucideIcons.tablet,
      _ => LucideIcons.monitor,
    };
    final meta = [
      if (s.location != null) s.location!,
      if (s.ipMasked != null) s.ipMasked!,
      if (s.lastActive != null) _relative(s.lastActive!),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: AppColors.inkSoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${s.os ?? 'Unknown'} · ${s.client ?? s.app ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (s.current) ...[
                      const SizedBox(width: 8),
                      const AccountPill(label: 'This device'),
                    ],
                  ],
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                    softWrap: true,
                  ),
                ],
              ],
            ),
          ),
          if (!s.current) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Sign out',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.logOut, size: 17, color: AppColors.danger),
              onPressed: () => _revokeSession(s),
            ),
          ],
        ],
      ),
    );
  }

  // --- notifications --------------------------------------------------------

  Widget _notificationsSection() {
    final prefs = _prefs!;
    return AccountSection(
      icon: LucideIcons.bell,
      title: 'Notifications',
      subtitle: 'Choose what reaches you, and on which channel.',
      children: [
        _channelMaster('Email', prefs.emailEnabled,
            (v) => _onTogglePrefs(prefs.copyWith(emailEnabled: v))),
        Divider(height: 1, color: AppColors.hairline2),
        _channelMaster('Push', prefs.pushEnabled,
            (v) => _onTogglePrefs(prefs.copyWith(pushEnabled: v))),
        const SizedBox(height: 8),
        if (context.isCompact)
          ..._notifEvents.map(_notifCard)
        else ...[
          _matrixHeader(),
          for (final e in _notifEvents) _matrixRow(e),
        ],
      ],
    );
  }

  Widget _channelMaster(String label, bool value, ValueChanged<bool> onChanged) {
    return SettingRow(
      label: '$label notifications',
      description: value ? 'On for all enabled events' : 'Silenced — nothing is delivered',
      icon: label == 'Email' ? LucideIcons.mail : LucideIcons.smartphone,
      trailing: HiveSwitch(value: value, onChanged: onChanged),
    );
  }

  Widget _matrixHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6, left: 2, right: 2),
      child: Row(
        children: [
          const Spacer(),
          _colLabel('Email'),
          const SizedBox(width: 16),
          _colLabel('Push'),
        ],
      ),
    );
  }

  Widget _colLabel(String label) => SizedBox(
        width: 40,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppColors.inkFaint,
          ),
        ),
      );

  ChannelPair _channelOf(String id) =>
      _prefs!.events[id] ?? const ChannelPair(email: false, push: false);

  void _setChannel(String id, {bool? email, bool? push}) {
    final events = Map<String, ChannelPair>.from(_prefs!.events);
    events[id] = _channelOf(id).copyWith(email: email, push: push);
    _onTogglePrefs(_prefs!.copyWith(events: events));
  }

  Widget _matrixRow(({String id, IconData icon, String label, String desc, bool locked}) e) {
    final pair = _channelOf(e.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(e.icon, size: 16, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                Text(e.desc,
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                    softWrap: true),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _matrixCell(
            locked: e.locked,
            value: pair.email,
            enabled: _prefs!.emailEnabled,
            onChanged: (v) => _setChannel(e.id, email: v),
          ),
          const SizedBox(width: 16),
          _matrixCell(
            locked: e.locked,
            value: pair.push,
            enabled: _prefs!.pushEnabled,
            onChanged: (v) => _setChannel(e.id, push: v),
          ),
        ],
      ),
    );
  }

  Widget _matrixCell({
    required bool locked,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      width: 40,
      child: Center(
        child: locked
            ? Tooltip(
                message: 'Always on',
                child: Icon(LucideIcons.lock, size: 15, color: AppColors.inkFaint),
              )
            : HiveSwitch(
                value: enabled && value,
                enabled: enabled,
                onChanged: enabled ? onChanged : null,
              ),
      ),
    );
  }

  /// Phone layout: one card per event with stacked Email / Push rows.
  Widget _notifCard(({String id, IconData icon, String label, String desc, bool locked}) e) {
    final pair = _channelOf(e.id);
    Widget channel(String label, bool value, bool enabled, ValueChanged<bool>? onChanged) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
            ),
            if (e.locked)
              const AccountPill(label: 'Always on')
            else
              HiveSwitch(
                value: enabled && value,
                enabled: enabled,
                onChanged: enabled ? onChanged : null,
              ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(e.icon, size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 9),
              Expanded(
                child: Text(e.label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(e.desc,
              style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft), softWrap: true),
          channel('Email', pair.email, _prefs!.emailEnabled,
              (v) => _setChannel(e.id, email: v)),
          channel('Push', pair.push, _prefs!.pushEnabled,
              (v) => _setChannel(e.id, push: v)),
        ],
      ),
    );
  }

  // --- access ---------------------------------------------------------------

  Widget _accessSection() {
    return AccountSection(
      icon: LucideIcons.layers,
      title: 'Access',
      subtitle: 'Teams and projects you belong to, with your role in each.',
      trailing: _AccessToggle(
        teams: _accessTeams,
        onChanged: (v) => setState(() => _accessTeams = v),
      ),
      children: [
        if (_accessTeams)
          if (_teams.isEmpty)
            _emptyRow('You’re not in any teams yet')
          else
            for (var i = 0; i < _teams.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.hairline2),
              _accessRow(
                glyph: _teams[i].key,
                color: HSLColor.fromAHSL(1, _teams[i].hue.toDouble(), 0.5, 0.55).toColor(),
                name: _teams[i].name,
                meta: '${_teams[i].members} members',
                role: _teams[i].role,
                onTap: () => context.go('/teams/${_teams[i].id}'),
              ),
            ]
        else if (_projects.isEmpty)
          _emptyRow('No projects you can access yet')
        else
          for (var i = 0; i < _projects.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.hairline2),
            _accessRow(
              glyph: _projects[i].key,
              color: _parseHex(_projects[i].color),
              name: _projects[i].name,
              meta: _projects[i].key,
              role: _projects[i].role,
              onTap: () => context.go('/issues?projectId=${_projects[i].id}'),
            ),
          ],
      ],
    );
  }

  Widget _accessRow({
    required String glyph,
    required Color color,
    required String name,
    required String meta,
    required String role,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: Text(
                glyph.isEmpty ? '?' : glyph.substring(0, glyph.length >= 3 ? 3 : glyph.length),
                style: TextStyle(
                  fontFamily: AppTheme.fontMono,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  Text(meta, style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AccountPill(label: role),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 16, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }

  // --- appearance (folded-in settings) --------------------------------------

  Widget _appearanceSection() {
    final config = context.watch<AppConfigBloc>().state;
    final locale = context.watch<LocaleCubit>().state;
    final themeMode = context.watch<ThemeCubit>().state;
    final isAdmin = context.read<AuthBloc>().state.user?.isAdmin ?? false;
    return AccountSection(
      icon: LucideIcons.sunMoon,
      title: 'Appearance & app',
      subtitle: 'Interface language, theme and workspace info.',
      children: [
        SettingRow(
          label: context.t('settings.language'),
          icon: LucideIcons.globe,
          stack: context.isCompact,
          trailing: DropdownButton<String>(
            value: locale.languageCode,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(14),
            items: [
              for (final entry in I18n.localeNames.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (code) =>
                code == null ? null : context.read<LocaleCubit>().setLocale(code),
          ),
        ),
        Divider(height: 1, color: AppColors.hairline2),
        SettingRow(
          label: context.t('settings.theme'),
          icon: LucideIcons.sunMoon,
          stack: context.isCompact,
          trailing: _ThemeSelector(
            mode: themeMode,
            onChanged: (m) => context.read<ThemeCubit>().setMode(m),
          ),
        ),
        if ((config.meta?.privacyPolicyUrl ?? '').isNotEmpty) ...[
          Divider(height: 1, color: AppColors.hairline2),
          SettingRow(
            label: context.t('settings.privacyPolicy'),
            icon: LucideIcons.shieldAlert,
            trailing: IconButton(
              icon: const Icon(LucideIcons.externalLink, size: 17),
              onPressed: () => launchUrl(Uri.parse(config.meta!.privacyPolicyUrl),
                  mode: LaunchMode.externalApplication),
            ),
          ),
        ],
        if (isAdmin) ...[
          Divider(height: 1, color: AppColors.hairline2),
          SettingRow(
            label: context.t('settings.adminArea'),
            icon: LucideIcons.shieldUser,
            trailing: IconButton(
              icon: const Icon(LucideIcons.chevronRight),
              onPressed: () => context.go('/admin'),
            ),
          ),
        ],
        Divider(height: 1, color: AppColors.hairline2),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              _aboutRow(context.t('settings.appVersion'), config.appVersion),
              _aboutRow(context.t('settings.serverVersion'), config.meta?.serverVersion ?? '–'),
              _aboutRow(context.t('settings.organization'), config.meta?.organizationName ?? '–'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aboutRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: AppColors.inkSoft, fontSize: 13))),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      );

  // --- data & privacy -------------------------------------------------------

  Widget _dataSection() {
    return AccountSection(
      icon: LucideIcons.fileText,
      title: 'Data & privacy',
      subtitle: 'Export a copy of your data (GDPR Art. 15).',
      children: [
        SettingRow(
          label: 'Request my data',
          description: 'A machine-readable export emailed to you, within 24 hours.',
          stack: context.isCompact,
          trailing: AccountActionButton(
            label: 'Request',
            icon: LucideIcons.download,
            onPressed: _dataReport,
          ),
        ),
      ],
    );
  }

  // --- danger zone ----------------------------------------------------------

  Widget _dangerSection() {
    return AccountSection(
      icon: LucideIcons.triangleAlert,
      title: 'Danger zone',
      subtitle: 'Irreversible account actions.',
      danger: true,
      children: [
        SettingRow(
          label: 'Delete my account',
          description: 'Permanently erase your account and anonymise your '
              'authored work (GDPR Art. 17).',
          stack: context.isCompact,
          trailing: AccountActionButton(
            label: 'Delete account',
            icon: LucideIcons.trash2,
            danger: true,
            onPressed: _deleteAccount,
          ),
        ),
      ],
    );
  }

  Widget _emptyRow(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(message,
            style: TextStyle(fontSize: 12.5, color: AppColors.inkFaint)),
      );

  // --- helpers --------------------------------------------------------------

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 2) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Color _parseHex(String hex) {
    final clean = hex.replaceAll('#', '');
    final value = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
    return value == null ? AppColors.stTodo : Color(value);
  }
}

class _AccessToggle extends StatelessWidget {
  const _AccessToggle({required this.teams, required this.onChanged});
  final bool teams;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              boxShadow: active
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1))]
                  : null,
            ),
            child: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.ink : AppColors.inkSoft,
                )),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('Teams', teams, () => onChanged(true)),
          seg('Projects', !teams, () => onChanged(false)),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.mode, required this.onChanged});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(ThemeMode, IconData, String)>[
      (ThemeMode.system, LucideIcons.monitor, 'settings.themeSystem'),
      (ThemeMode.light, LucideIcons.sun, 'settings.themeLight'),
      (ThemeMode.dark, LucideIcons.moon, 'settings.themeDark'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (m, icon, labelKey) in options)
            Tooltip(
              message: context.t(labelKey),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: m == mode ? AppColors.accentSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon,
                      size: 17,
                      color: m == mode ? AppColors.accentStrong : AppColors.inkSoft),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
