import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/models/core_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hue_colors.dart';
import '../../../core/widgets/hive_widgets.dart';
import '../../../core/widgets/soft_card.dart';

/// One settings card: a [SoftCard] with a [SectionHeader] and body, spaced like
/// the design's `.ps-block`.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.child,
    this.note,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final Widget child;
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  title: title,
                  actionLabel: actionLabel,
                  onAction: onAction,
                ),
              ),
              ?trailing,
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.inkSoft,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Field label with an optional "required" pill, mirroring `.ps-field label`.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
          if (required) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                context.t('projectSettings.required'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.accentStrong,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small round color dot that opens the hue picker when tapped.
class HueDot extends StatelessWidget {
  const HueDot({
    super.key,
    required this.hue,
    required this.onTap,
    this.size = 14,
  });

  final int hue;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: hueColor(hue),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 1,
              spreadRadius: 0.3,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet hue picker (bounded to the viewport — never overflows). Returns
/// the chosen hue, or null on dismiss.
Future<int?> showHuePicker(
  BuildContext context, {
  required int current,
  List<int> hues = kLabelHues,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.surface,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sheetContext.t('projectSettings.chooseColor'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final h in hues)
                  GestureDetector(
                    onTap: () => Navigator.of(sheetContext).pop(h),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: hueColor(h),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: h == current
                              ? AppColors.ink
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: h == current
                          ? const Icon(
                              LucideIcons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Multi-select people picker for adding project members. Returns the chosen
/// user ids, or null on cancel.
Future<List<String>?> showMemberPicker(
  BuildContext context, {
  required List<DirectoryUser> candidates,
  required String projectName,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) =>
        _MemberPicker(candidates: candidates, projectName: projectName),
  );
}

class _MemberPicker extends StatefulWidget {
  const _MemberPicker({required this.candidates, required this.projectName});

  final List<DirectoryUser> candidates;
  final String projectName;

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  final _selected = <String>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.candidates.where((u) {
      final q = _query.toLowerCase();
      return q.isEmpty ||
          u.displayName.toLowerCase().contains(q) ||
          (u.title ?? '').toLowerCase().contains(q);
    }).toList();
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('projectSettings.addMembers'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          context.t(
                            'projectSettings.addMembersSub',
                            variables: {'name': widget.projectName},
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  hintText: context.t('projectSettings.searchPeople'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        context.t('projectSettings.everyoneMember'),
                        style: TextStyle(color: AppColors.inkSoft),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final u = filtered[i];
                        final on = _selected.contains(u.id);
                        return ListTile(
                          onTap: () => setState(
                            () => on
                                ? _selected.remove(u.id)
                                : _selected.add(u.id),
                          ),
                          leading: HiveAvatar(
                            name: u.displayName,
                            imageUrl: u.avatarUrl,
                            size: 36,
                          ),
                          title: Text(
                            u.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: u.title == null ? null : Text(u.title!),
                          trailing: Icon(
                            on
                                ? LucideIcons.circleCheckBig
                                : LucideIcons.circle,
                            color: on ? AppColors.accent : AppColors.inkFaint,
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t('common.cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        icon: LucideIcons.userPlus,
                        label: _selected.isEmpty
                            ? context.t('projectSettings.add')
                            : context.t(
                                'projectSettings.addN',
                                variables: {'count': '${_selected.length}'},
                              ),
                        onPressed: _selected.isEmpty
                            ? null
                            : () =>
                                  Navigator.of(context).pop(_selected.toList()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brief snackbar feedback (mirrors the reference's `H.toast`).
void settingsToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        duration: const Duration(seconds: 2),
      ),
    );
}

/// Shared input decoration matching `.ps-input`.
InputDecoration settingsInput(
  BuildContext context, {
  String? hint,
  bool error = false,
  Widget? suffix,
}) {
  return InputDecoration(
    isDense: true,
    hintText: hint,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      borderSide: BorderSide(
        color: error ? AppColors.danger : AppColors.hairline,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      borderSide: BorderSide(
        color: error ? AppColors.danger : AppColors.accent,
        width: 1.6,
      ),
    ),
  );
}
