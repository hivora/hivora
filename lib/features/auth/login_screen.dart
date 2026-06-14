import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/widgets/hive_loader.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/hivora_repository.dart';
import '../../core/blocs/app_config_bloc.dart';
import '../../core/blocs/auth_bloc.dart';
import '../../core/i18n/i18n.dart';
import '../../core/models/core_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/soft_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  List<SsoProvider> _providers = const [];

  /// Id of the SSO provider currently launching, or null. Drives the per-button
  /// loader; combined with [AuthStatus.authenticating] it disables every button
  /// so no second login can start while one is in flight.
  String? _launchingSsoId;

  @override
  void initState() {
    super.initState();
    _loadProviders();
    _showSsoErrorIfPresent();
  }

  /// The server redirects failed SSO logins to `/login?ssoError=message`.
  void _showSsoErrorIfPresent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final error =
          GoRouterState.of(context).uri.queryParameters['ssoError'];
      if (error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.t('auth.ssoFailed')}: $error')),
        );
      }
    });
  }

  Future<void> _loadProviders() async {
    try {
      final providers = await context.read<HivoraRepository>().ssoProviders();
      if (mounted) setState(() => _providers = providers);
    } catch (_) {
      // SSO buttons are optional; password login stays available.
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final organization =
        context.select((AppConfigBloc bloc) => bloc.state.meta?.organizationName);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state.errorKey != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.t(state.errorKey!))),
                    );
                  }
                },
                builder: (context, state) {
                  final passwordBusy =
                      state.status == AuthStatus.authenticating;
                  // While any login is in flight every button is disabled, so a
                  // second flow can't start on top of the first.
                  final busy = passwordBusy || _launchingSsoId != null;
                  return SoftCard(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            organization ?? 'Hivora',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.t('auth.subtitle'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _identifier,
                            enabled: !busy,
                            autofillHints: const [AutofillHints.username],
                            decoration: InputDecoration(
                              labelText: context.t('auth.identifier'),
                              prefixIcon: const Icon(Icons.person_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? context.t('errors.required')
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            enabled: !busy,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: context.t('auth.password'),
                              prefixIcon: const Icon(Icons.lock_rounded),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? context.t('errors.required')
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: busy ? null : _submit,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: passwordBusy
                                  ? const SizedBox(
                                      key: ValueKey('loader'),
                                      width: 22,
                                      height: 22,
                                      child: HiveLoader(
                                          size: 22,
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Text(context.t('auth.signIn'),
                                      key: const ValueKey('label')),
                            ),
                          ),
                          if (_providers.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    context.t('auth.or'),
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            for (final provider in _providers)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: OutlinedButton.icon(
                                  onPressed:
                                      busy ? null : () => _launchSso(provider),
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _launchingSsoId == provider.id
                                        ? const SizedBox(
                                            key: ValueKey('loader'),
                                            width: 18,
                                            height: 18,
                                            child: HiveLoader(
                                                size: 18, strokeWidth: 2),
                                          )
                                        : const Icon(Icons.shield_rounded,
                                            size: 18, key: ValueKey('icon')),
                                  ),
                                  label: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _launchingSsoId == provider.id
                                        ? Text(context.t('auth.signingIn'),
                                            key: const ValueKey('signing'))
                                        : Text(
                                            context.t('auth.continueWith',
                                                variables: {
                                                  'provider': provider.displayName
                                                }),
                                            key: const ValueKey('continue')),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context
          .read<AuthBloc>()
          .add(LoginSubmitted(_identifier.text.trim(), _password.text));
    }
  }

  Future<void> _launchSso(SsoProvider provider) async {
    final serverUrl = context.read<AuthBloc>().storage.serverUrl ?? '';
    var uri = Uri.parse('$serverUrl${provider.loginUrl}');
    setState(() => _launchingSsoId = provider.id);
    try {
      // Let the disabled/loading state actually reach the screen before we
      // hand the tab to the browser. On web `launchUrl('_self')` changes
      // window.location synchronously and tears this page down; a single
      // endOfFrame fires before the rasterized frame is composited, so the
      // loader was being skipped. A short delay lets the browser paint a few
      // frames (loader visible, buttons disabled) first.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      if (kIsWeb) {
        // Web: tell the server where to return; the whole flow stays in this
        // tab and ends at <origin>/#/auth-callback with the token pair.
        uri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'return': Uri.base.origin,
        });
        await launchUrl(uri, webOnlyWindowName: '_self');
        // The tab is on its way to the SSO provider and the flow finishes by
        // redirecting back. Keep the buttons disabled — re-enabling them lets
        // the user start a second login while this one completes in the
        // background, which is exactly the bug we're fixing.
        return;
      }
      // Native: the server redirects back via hivora://auth-callback.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // The external browser took over; restore the buttons so the user can
      // retry if they return without completing the login.
      if (mounted) setState(() => _launchingSsoId = null);
    } catch (_) {
      // Launch failed before the redirect — restore the buttons to try again.
      if (mounted) setState(() => _launchingSsoId = null);
    }
  }
}
