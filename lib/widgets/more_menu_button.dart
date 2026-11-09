import 'package:flutter/cupertino.dart';

import '../screens/settings_screen.dart';
import '../theme/app_colors.dart';

/// A single screen-specific row in the "…" menu, shown above the
/// always-present items.
class MoreMenuAction {
  const MoreMenuAction({required this.label, required this.onSelected});

  final String label;
  final void Function(BuildContext context) onSelected;
}

/// Top-right "…" button shown on every tab's navigation bar. Opens a
/// pull-down style action sheet with always-present items (設定,
/// データをエクスポート, アカウント, このアプリについて) plus any
/// screen-specific [extraActions] the caller passes in.
class MoreMenuButton extends StatelessWidget {
  const MoreMenuButton({this.extraActions = const [], super.key});

  final List<MoreMenuAction> extraActions;

  Future<void> _show(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          for (final action in extraActions)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                action.onSelected(context);
              },
              child: Text(action.label),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            child: const Text('設定'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              exportEntriesJson(context);
            },
            child: const Text('データをエクスポート'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            child: const Text('アカウント'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            child: const Text('このアプリについて'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('キャンセル'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => _show(context),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.borderLine.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: const Icon(CupertinoIcons.ellipsis, size: 18, color: AppColors.inkPrimary),
      ),
    );
  }
}
