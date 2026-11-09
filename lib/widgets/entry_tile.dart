import 'package:flutter/cupertino.dart';

import '../models/entry.dart';
import '../theme/app_colors.dart';

/// A single row in the Home list: a status dot, term + reading on the
/// left, Myanmar meaning on the right.
class EntryTile extends StatelessWidget {
  const EntryTile({required this.entry, required this.onTap, super.key});

  final Entry entry;
  final VoidCallback onTap;

  Color get _statusColor {
    if (entry.isMastered) return AppColors.successGreen;
    if (entry.isLearning) return AppColors.hankoRed;
    return AppColors.borderLine;
  }

  @override
  Widget build(BuildContext context) {
    final hasReading = entry.reading != null && entry.reading!.trim().isNotEmpty;
    return CupertinoListTile(
      onTap: onTap,
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
      ),
      title: Text(
        entry.term,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.inkPrimary,
        ),
      ),
      subtitle: hasReading
          ? Text(
              entry.reading!,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
            )
          : null,
      additionalInfo: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(
          entry.meaningMy,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.inkPrimary,
          ),
        ),
      ),
      trailing: const CupertinoListTileChevron(),
    );
  }
}
