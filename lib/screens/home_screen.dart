import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

import '../app_scope.dart';
import '../models/entry.dart';
import '../theme/app_colors.dart';
import '../widgets/entry_tile.dart';
import '../widgets/speak_button.dart';
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
            final entries = repo.byType(_type);
            final dailyEntry = _pickDailyEntry(repo.byType(EntryType.tango));
            return Column(
              children: [
                if (dailyEntry != null) _DailyPromptCard(entry: dailyEntry),
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

  /// Picks one tango [Entry] to feature as "today's prompt" — prefers an
  /// entry not yet mastered, and is stable for the whole day (rotates once
  /// per day) rather than re-randomizing on every rebuild.
  Entry? _pickDailyEntry(List<Entry> tangoEntries) {
    if (tangoEntries.isEmpty) return null;
    final notMastered = tangoEntries.where((e) => !e.isMastered).toList();
    final pool = notMastered.isNotEmpty ? notMastered : tangoEntries;
    final dayIndex = DateTime.now().difference(DateTime(2020)).inDays;
    return pool[dayIndex % pool.length];
  }
}

/// "今日のお題" card: suggests saying one known word out loud when the user
/// spots it in daily life — the real-world-output practice from the
/// language-acquisition research this was built from.
class _DailyPromptCard extends StatelessWidget {
  const _DailyPromptCard({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日のお題',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '身の回りで「${entry.term}」を見つけたら、声に出して言ってみましょう。',
                  style: const TextStyle(fontSize: 14, color: AppColors.inkPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SpeakButton(text: entry.term),
        ],
      ),
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
