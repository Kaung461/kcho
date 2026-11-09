import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

import '../app_scope.dart';
import '../models/entry.dart';
import '../theme/app_colors.dart';
import '../widgets/entry_tile.dart';
import '../widgets/type_segmented_control.dart';
import 'add_entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  EntryType _type = EntryType.tango;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // The segmented control's custom TextStyle isn't compatible with the
        // nav bar's automatic title Hero transition (mismatched
        // TextStyle.inherit crashes on mount) — turn that transition off.
        transitionBetweenRoutes: false,
        middle: SizedBox(
          width: 220,
          child: TypeSegmentedControl(
            value: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => AddEntryScreen(initialType: _type),
            ),
          ),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: ValueListenableBuilder<Box<Entry>>(
          valueListenable: repo.listenable(),
          builder: (context, _, __) {
            final all = repo.all();
            final entries = repo.byType(_type);
            return Column(
              children: [
                _TodayStatusBar(entries: all),
                Expanded(
                  child: entries.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => Container(
                            margin: const EdgeInsets.only(left: 16),
                            height: 0.5,
                            color: AppColors.borderLine,
                          ),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return EntryTile(
                              entry: entry,
                              onTap: () => Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => AddEntryScreen(existing: entry),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Thin "today's status" bar shown above the list: how many entries were
/// reviewed today, and how many are due. Both are derived straight from
/// existing Entry fields (lastReviewed, nextReviewDate) — no new tracking.
class _TodayStatusBar extends StatelessWidget {
  const _TodayStatusBar({required this.entries});

  final List<Entry> entries;

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final reviewedToday = entries.where((e) => _isToday(e.lastReviewed)).length;
    final dueToday = entries.where((e) => e.isDue).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: '今日復習した', value: reviewedToday),
          Container(width: 0.5, height: 28, color: AppColors.borderLine),
          _Stat(label: '復習予定', value: dueToday),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.hankoRed,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'まだ登録がありません。\n右上の + から追加してください。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.inkSecondary,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
