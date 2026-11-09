import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

import '../app_scope.dart';
import '../models/entry.dart';
import '../theme/app_colors.dart';
import '../widgets/entry_tile.dart';
import '../widgets/more_menu_button.dart';
import '../widgets/reading_home_section.dart';
import 'add_entry_screen.dart';

enum _HomeMode { tango, grammar, weak, reading }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeMode _mode = _HomeMode.tango;

  EntryType get _type => _mode == _HomeMode.grammar ? EntryType.grammar : EntryType.tango;

  void _selectMode(_HomeMode mode) => setState(() => _mode = mode);

  void _openAdd(BuildContext context) => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => AddEntryScreen(initialType: _type)),
      );

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);

    return CupertinoPageScaffold(
      child: SafeArea(
        child: ValueListenableBuilder<Box<Entry>>(
          valueListenable: repo.listenable(),
          builder: (context, _, __) {
            final all = repo.all();
            List<Entry> listed = const [];
            switch (_mode) {
              case _HomeMode.tango:
                listed = repo.byType(EntryType.tango);
              case _HomeMode.grammar:
                listed = repo.byType(EntryType.grammar);
              case _HomeMode.weak:
                listed = all.where((e) => e.wrongCount > e.correctCount).toList();
              case _HomeMode.reading:
                break;
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(onAdd: () => _openAdd(context))),
                SliverToBoxAdapter(child: _HeroCard(entries: all)),
                SliverToBoxAdapter(
                  child: _ShortcutTiles(
                    mode: _mode,
                    onSelectTango: () => _selectMode(_HomeMode.tango),
                    onSelectGrammar: () => _selectMode(_HomeMode.grammar),
                    onSelectReading: () => _selectMode(_HomeMode.reading),
                    onSelectWeak: () => _selectMode(_HomeMode.weak),
                  ),
                ),
                const SliverToBoxAdapter(child: _StreakStrip()),
                const SliverToBoxAdapter(child: SizedBox(height: 4)),
                if (_mode == _HomeMode.reading)
                  const ReadingHomeSection()
                else if (all.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _FreshEmptyState(onAdd: () => _openAdd(context)),
                  )
                else if (listed.isEmpty)
                  SliverToBoxAdapter(child: _FilteredEmptyState(weak: _mode == _HomeMode.weak))
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = listed[index];
                        return Column(
                          children: [
                            EntryTile(
                              entry: entry,
                              onTap: () => Navigator.of(context).push(
                                CupertinoPageRoute<void>(builder: (_) => AddEntryScreen(existing: entry)),
                              ),
                            ),
                            if (index != listed.length - 1)
                              Container(
                                margin: const EdgeInsets.only(left: 16),
                                height: 0.5,
                                color: AppColors.borderLine,
                              ),
                          ],
                        );
                      },
                      childCount: listed.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// App name + short greeting on the left, add / "…" buttons on the right.
/// Replaces the old plain nav bar so the page reads as one continuous
/// scroll, matching the reference layouts.
class _Header extends StatelessWidget {
  const _Header({required this.onAdd});

  final VoidCallback onAdd;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'おはようございます';
    if (hour < 18) return 'こんにちは';
    return 'こんばんは';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'K帳',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.inkPrimary),
                ),
                const SizedBox(height: 2),
                Text(_greeting, style: const TextStyle(fontSize: 14, color: AppColors.inkSecondary)),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onAdd,
            child: const Icon(CupertinoIcons.add_circled, size: 30, color: AppColors.hankoRed),
          ),
          const SizedBox(width: 8),
          const MoreMenuButton(),
        ],
      ),
    );
  }
}

/// Rounded hero card: today's due count, a mastered/total progress bar.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.entries});

  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final total = entries.length;
    final mastered = entries.where((e) => e.isMastered).length;
    final dueToday = entries.where((e) => e.isDue).length;
    final fraction = total == 0 ? 0.0 : mastered / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkPrimary.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日の復習',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '$dueToday 件',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.hankoRed),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: AppColors.borderLine,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction.clamp(0, 1),
                child: Container(color: AppColors.successGreen),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('マスター済み $mastered', style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary)),
              Text('登録 $total', style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 4 shortcut tiles: 単語/文法 filter the list below, 読解 jumps to the
/// Reading tab, 苦手 filters to entries answered wrong more than right.
class _ShortcutTiles extends StatelessWidget {
  const _ShortcutTiles({
    required this.mode,
    required this.onSelectTango,
    required this.onSelectGrammar,
    required this.onSelectReading,
    required this.onSelectWeak,
  });

  final _HomeMode mode;
  final VoidCallback onSelectTango;
  final VoidCallback onSelectGrammar;
  final VoidCallback onSelectReading;
  final VoidCallback onSelectWeak;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _ShortcutTile(
              icon: CupertinoIcons.textformat_abc,
              label: '単語',
              selected: mode == _HomeMode.tango,
              onTap: onSelectTango,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ShortcutTile(
              icon: CupertinoIcons.text_badge_checkmark,
              label: '文法',
              selected: mode == _HomeMode.grammar,
              onTap: onSelectGrammar,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ShortcutTile(
              icon: CupertinoIcons.doc_text_search,
              label: '読解',
              selected: mode == _HomeMode.reading,
              onTap: onSelectReading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ShortcutTile(
              icon: CupertinoIcons.exclamationmark_circle,
              label: '苦手',
              selected: mode == _HomeMode.weak,
              onTap: onSelectWeak,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.hankoRed.withValues(alpha: 0.12) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.hankoRed.withValues(alpha: 0.5) : AppColors.borderLine,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? AppColors.hankoRed : AppColors.inkSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.hankoRed : AppColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// This week (日〜土) with a filled dot on days that had at least one quiz
/// answer, today outlined; current streak on the right.
class _StreakStrip extends StatelessWidget {
  const _StreakStrip();

  static const _weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final log = AppScope.studyLogOf(context);
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: log.listenable(),
      builder: (context, _, __) {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
        final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLine),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final day in days)
                      _DayDot(
                        label: _weekdayLabels[day.weekday % 7],
                        studied: log.reviewedOn(day) > 0,
                        isToday: _isSameDay(day, now),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${log.currentStreak}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.hankoRed),
                  ),
                  const Text('連続日', style: TextStyle(fontSize: 11, color: AppColors.inkSecondary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.label, required this.studied, required this.isToday});

  final String label;
  final bool studied;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: studied ? AppColors.hankoRed : AppColors.paperBackground,
            border: Border.all(
              color: isToday ? AppColors.hankoRed : AppColors.borderLine,
              width: isToday ? 1.5 : 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkSecondary)),
      ],
    );
  }
}

class _FreshEmptyState extends StatelessWidget {
  const _FreshEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'まだ登録がありません。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkSecondary, fontSize: 15),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: onAdd,
              child: const Text('＋ 最初の単語を追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.weak});

  final bool weak;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          weak ? '苦手な項目はまだありません。\nクイズで間違えた項目がここに表示されます。' : 'この種類の登録がまだありません。',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSecondary, fontSize: 15),
        ),
      ),
    );
  }
}
