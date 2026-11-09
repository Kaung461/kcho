import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

import '../app_scope.dart';
import '../models/entry.dart';
import '../services/settings_store.dart';
import '../theme/app_colors.dart';
import '../widgets/more_menu_button.dart';

const List<String> _weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final studyLog = AppScope.studyLogOf(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text('進捗'),
        trailing: MoreMenuButton(),
      ),
      child: SafeArea(
        child: ValueListenableBuilder<Box<Entry>>(
          valueListenable: repo.listenable(),
          builder: (context, _, __) {
            final entries = repo.all();
            final total = entries.length;
            final mastered = entries.where((e) => e.isMastered).length;
            final newToday = entries.where((e) => _isToday(e.createdAt)).length;
            final totalCorrect = entries.fold<int>(0, (sum, e) => sum + e.correctCount);
            final totalWrong = entries.fold<int>(0, (sum, e) => sum + e.wrongCount);
            final accuracy = (totalCorrect + totalWrong) == 0
                ? null
                : totalCorrect / (totalCorrect + totalWrong);

            return ValueListenableBuilder<Box<dynamic>>(
              valueListenable: studyLog.listenable(),
              builder: (context, _, __) {
                final reviewedToday = studyLog.reviewedToday;
                final streak = studyLog.currentStreak;
                final daysStudied = studyLog.daysStudied;
                final last7 = studyLog.lastNDays(7);
                final daysThisWeek = last7.where((c) => c > 0).length;

                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    const _SectionLabel('今日'),
                    _StatRow(
                      children: [
                        _StatTile(
                          icon: CupertinoIcons.checkmark_circle,
                          label: '復習した数',
                          value: '$reviewedToday',
                        ),
                        _StatTile(
                          icon: CupertinoIcons.plus_circle,
                          label: '新しく登録',
                          value: '$newToday',
                        ),
                      ],
                    ),
                    const _SectionLabel('累計'),
                    _StatRow(
                      children: [
                        _StatTile(
                          icon: CupertinoIcons.book,
                          label: '登録語数',
                          value: '$total',
                        ),
                        _StatTile(
                          icon: CupertinoIcons.star,
                          label: 'マスター済み',
                          value: '$mastered',
                        ),
                        _StatTile(
                          icon: CupertinoIcons.chart_bar_alt_fill,
                          label: '正答率',
                          value: accuracy == null ? '—' : '${(accuracy * 100).round()}%',
                        ),
                      ],
                    ),
                    const _SectionLabel('連続・学習日数'),
                    _StatRow(
                      children: [
                        _StatTile(
                          icon: CupertinoIcons.flame,
                          label: '連続日数',
                          value: '$streak 日',
                        ),
                        _StatTile(
                          icon: CupertinoIcons.calendar,
                          label: '学習日数',
                          value: '$daysStudied 日',
                        ),
                      ],
                    ),
                    const _SectionLabel('目標の進捗'),
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLine),
                      ),
                      child: Column(
                        children: [
                          FutureBuilder<int>(
                            future: SettingsStore().getGoalWordCount(),
                            builder: (context, snapshot) {
                              final goal = snapshot.data ?? SettingsStore.defaultGoalWordCount;
                              return _LabeledProgressBar(
                                label: 'マスター済み',
                                current: mastered,
                                total: goal,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _LabeledProgressBar(
                            label: '今週の復習日数',
                            current: daysThisWeek,
                            total: 7,
                          ),
                        ],
                      ),
                    ),
                    const _SectionLabel('最近7日'),
                    _WeeklyBarChart(counts: last7),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSecondary),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.hankoRed),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.hankoRed),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary)),
        ],
      ),
    );
  }
}

class _LabeledProgressBar extends StatelessWidget {
  const _LabeledProgressBar({required this.label, required this.current, required this.total});

  final String label;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : current / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkPrimary),
            ),
            Text('$current / $total', style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: AppColors.borderLine,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0, 1),
              child: Container(color: AppColors.hankoRed),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple custom bar chart (no chart package) for the last 7 days of
/// review counts, oldest first / today last.
class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final maxVal = counts.fold<int>(0, (m, v) => v > m ? v : m);
    final now = DateTime.now();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < counts.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${counts[i]}', style: const TextStyle(fontSize: 10, color: AppColors.inkSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      height: 8 + (maxVal == 0 ? 0.0 : counts[i] / maxVal) * 52,
                      decoration: BoxDecoration(
                        color: counts[i] > 0 ? AppColors.hankoRed : AppColors.borderLine,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _weekdayLabels[now.subtract(Duration(days: counts.length - 1 - i)).weekday % 7],
                      style: const TextStyle(fontSize: 11, color: AppColors.inkSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
