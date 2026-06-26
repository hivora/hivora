import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/hex_mark.dart';
import '../../core/widgets/hive_loader.dart';

/// Brief branded splash shown while the app (re)connects to a server that is
/// already known — e.g. on boot with a saved server, or right after switching
/// servers. Distinct from [ConnectScreen], which is the URL-entry screen shown
/// only when no server is configured yet (or a connection failed).
class ConnectingScreen extends StatelessWidget {
  const ConnectingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HexMark(size: 56),
              const SizedBox(height: 28),
              const HiveLoader(size: 26, strokeWidth: 2),
              const SizedBox(height: 18),
              Text(
                context.t('connect.connecting'),
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
