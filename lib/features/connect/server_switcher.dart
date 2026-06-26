import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/blocs/app_config_bloc.dart';
import '../../core/i18n/i18n.dart';
import '../../core/models/server_profile.dart';
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_popup_menu.dart';
import '../sprint/modals/glass_modal.dart'
    show GlassField, GlassModalFooter, GlassModalHeader, glassInputDecoration, showGlassModal;

/// Sentinel value used by the switcher popup for the "add another server" row.
const _kAddServer = '__add_server__';

/// Switches the app to an already-saved [url]: points the storage at it and asks
/// AppConfig to re-verify the new backend. Auth is re-checked centrally once the
/// switch settles (see `HinataApp._onAppConfig`), so the user either lands back
/// in the app (the server has a stored token) or on its sign-in screen.
Future<void> switchToServer(BuildContext context, String url) async {
  final storage = context.read<AppStorage>();
  if (storage.serverUrl == url) return;
  final appConfig = context.read<AppConfigBloc>();
  await storage.setCurrentServer(url);
  appConfig.add(const AppConfigStarted());
}

/// Opens the "add server" dialog. On confirm it hands the URL to AppConfig
/// (which normalizes + verifies it and makes it current); the router then shows
/// the connecting splash and routes onward — to sign-in for the new server.
Future<void> showAddServerDialog(BuildContext context) {
  return showGlassModal<void>(
    context,
    width: 460,
    builder: (_) => const _AddServerForm(),
  );
}

class _AddServerForm extends StatefulWidget {
  const _AddServerForm();

  @override
  State<_AddServerForm> createState() => _AddServerFormState();
}

class _AddServerFormState extends State<_AddServerForm> {
  final _controller = TextEditingController(text: 'https://');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      setState(() => _error = context.t('connect.invalidUrl'));
      return;
    }
    // AppConfig normalizes (trim + strip trailing slash), persists and verifies.
    context.read<AppConfigBloc>().add(ServerUrlSubmitted(raw));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassModalHeader(
          icon: LucideIcons.serverCog,
          title: context.t('server.addTitle'),
          subtitle: context.t('server.addSubtitle'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
          child: GlassField(
            label: context.t('connect.serverUrl'),
            child: TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              autofillHints: const [AutofillHints.url],
              decoration: glassInputDecoration(hint: 'https://hinata.example.org'),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
            child: Row(
              children: [
                const Icon(LucideIcons.triangleAlert,
                    size: 15, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        GlassModalFooter(
          confirmLabel: context.t('server.addConfirm'),
          confirmIcon: LucideIcons.plus,
          onConfirm: _submit,
        ),
      ],
    );
  }
}

/// A compact "current server" pill that opens a glass popup to switch between
/// saved servers or add a new one. Drop it on the login screen and anywhere a
/// signed-in user should be able to hop backends.
class ServerSwitcher extends StatelessWidget {
  const ServerSwitcher({super.key, this.width = 260});

  /// Width of the popup menu.
  final double width;

  @override
  Widget build(BuildContext context) {
    final storage = context.read<AppStorage>();
    final current = storage.serverUrl;
    final servers = storage.servers;
    final currentProfile = servers.firstWhere(
      (s) => s.url == current,
      orElse: () => ServerProfile(url: current ?? ''),
    );

    final items = <GlassMenuItem<String>>[
      for (final server in servers)
        GlassMenuItem<String>(
          value: server.url,
          label: server.displayName,
          leading: const Icon(LucideIcons.server, size: 16),
        ),
      GlassMenuItem<String>(
        value: _kAddServer,
        label: context.t('server.addAnother'),
        leading: const Icon(LucideIcons.plus, size: 16),
        dividerAbove: servers.isNotEmpty,
      ),
    ];

    return GlassPopupMenu<String>(
      items: items,
      value: current ?? '',
      width: width,
      onSelected: (value) {
        if (value == _kAddServer) {
          showAddServerDialog(context);
        } else {
          switchToServer(context, value);
        }
      },
      child: _Pill(label: currentProfile.displayName),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.server, size: 15, color: AppColors.accentStrong),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          Icon(LucideIcons.chevronsUpDown, size: 14, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}
