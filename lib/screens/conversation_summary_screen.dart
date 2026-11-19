import 'package:flutter/cupertino.dart';

import '../models/entry.dart';
import '../theme/app_colors.dart';

enum ConversationSummaryAction { restart, close }

/// Calm end-of-session recap for 会話練習: which of today's target words
/// got used, and every correction the AI made along the way (capped at 5).
class ConversationSummaryScreen extends StatelessWidget {
  const ConversationSummaryScreen({
    required this.targets,
    required this.usedTargetIds,
    required this.corrections,
    super.key,
  });

  final List<Entry> targets;
  final Set<String> usedTargetIds;
  final List<String> corrections;

  @override
  Widget build(BuildContext context) {
    final usedCount = targets.where((e) => usedTargetIds.contains(e.id)).length;
    final shownCorrections =
        corrections.length > 5 ? corrections.sublist(corrections.length - 5) : corrections;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('会話のまとめ')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (targets.isNotEmpty) ...[
              Text(
                '今日の単語を使えた数: $usedCount / ${targets.length}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.inkPrimary),
              ),
              const SizedBox(height: 16),
              ...targets.map(
                (entry) => _WordRow(entry: entry, used: usedTargetIds.contains(entry.id)),
              ),
              const SizedBox(height: 24),
            ],
            if (shownCorrections.isNotEmpty) ...[
              const Text(
                'ひとこと添削',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 8),
              ...shownCorrections.map(
                (text) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLine),
                  ),
                  child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.inkPrimary, height: 1.4)),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    color: AppColors.hankoRed,
                    onPressed: () => Navigator.of(context).pop(ConversationSummaryAction.restart),
                    child: const Text('もう一度'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    color: AppColors.borderLine,
                    onPressed: () => Navigator.of(context).pop(ConversationSummaryAction.close),
                    child: const Text('閉じる', style: TextStyle(color: AppColors.inkPrimary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.entry, required this.used});

  final Entry entry;
  final bool used;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            used ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
            size: 18,
            color: used ? AppColors.successGreen : AppColors.inkSecondary,
          ),
          const SizedBox(width: 8),
          Text(entry.term, style: const TextStyle(fontSize: 15, color: AppColors.inkPrimary)),
        ],
      ),
    );
  }
}
