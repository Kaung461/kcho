import 'dart:math';

import 'package:flutter/cupertino.dart';

import '../app_scope.dart';
import '../services/quiz_service.dart';
import '../services/settings_store.dart';
import '../services/sm2_service.dart';
import '../theme/app_colors.dart';
import '../widgets/speak_button.dart';

QuizDifficulty _difficultyFromSetting(String value) => switch (value) {
      'easy' => QuizDifficulty.easy,
      'normal' => QuizDifficulty.normal,
      _ => QuizDifficulty.hard,
    };

String _difficultyToSetting(QuizDifficulty value) => switch (value) {
      QuizDifficulty.easy => 'easy',
      QuizDifficulty.normal => 'normal',
      QuizDifficulty.hard => 'hard',
    };

/// How many questions a session asks for, before however many entries are
/// actually eligible caps it — see [QuizService.buildSession]'s own
/// [QuizService.sessionSize] ceiling, which [all] maps to.
enum QuizSessionSize { five, ten, all }

int _questionCountFor(QuizSessionSize size) => switch (size) {
      QuizSessionSize.five => 5,
      QuizSessionSize.ten => 10,
      QuizSessionSize.all => QuizService.sessionSize,
    };

QuizSessionSize _sessionSizeFromSetting(String value) => switch (value) {
      '5' => QuizSessionSize.five,
      'all' => QuizSessionSize.all,
      _ => QuizSessionSize.ten,
    };

String _sessionSizeToSetting(QuizSessionSize value) => switch (value) {
      QuizSessionSize.five => '5',
      QuizSessionSize.ten => '10',
      QuizSessionSize.all => 'all',
    };

const Duration _advanceDelay = Duration(milliseconds: 900);

/// Quiz body — embedded inside [ReviewScreen] alongside [FlashcardView].
/// No Scaffold/nav bar of its own.
class QuizView extends StatefulWidget {
  const QuizView({super.key});

  @override
  State<QuizView> createState() => _QuizViewState();
}

enum _Phase { idle, running, done }

class _QuizViewState extends State<QuizView> {
  final Random _rng = Random();
  final SettingsStore _settings = SettingsStore();

  _Phase _phase = _Phase.idle;
  List<QuizQuestion> _questions = [];
  int _current = 0;
  int _score = 0;
  int _streak = 0;
  int? _selectedIndex;
  bool _answered = false;
  final List<_WrongAnswer> _wrongAnswers = [];
  final List<String> _newlyMastered = [];
  bool _allDueSession = false;

  QuizDifficulty _difficulty = QuizDifficulty.hard;
  QuizSessionSize _sessionSize = QuizSessionSize.ten;

  @override
  void initState() {
    super.initState();
    _settings.getQuizDifficulty().then((value) {
      if (mounted) setState(() => _difficulty = _difficultyFromSetting(value));
    });
    _settings.getQuizSessionSize().then((value) {
      if (mounted) setState(() => _sessionSize = _sessionSizeFromSetting(value));
    });
  }

  void _onDifficultyChanged(QuizDifficulty value) {
    setState(() => _difficulty = value);
    _settings.setQuizDifficulty(_difficultyToSetting(value));
  }

  void _onSessionSizeChanged(QuizSessionSize value) {
    setState(() => _sessionSize = value);
    _settings.setQuizSessionSize(_sessionSizeToSetting(value));
  }

  void _start() {
    final repo = AppScope.of(context);
    final confusions = AppScope.quizConfusionsOf(context);
    final pool = repo.all().where((e) => e.meaningMy.trim().isNotEmpty).toList();
    if (pool.length < 4) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('登録が足りません'),
          content: const Text('クイズには4件以上の登録が必要です。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final now = DateTime.now();
    final questions = QuizService.buildSession(
      repo,
      random: _rng,
      questionCount: _questionCountFor(_sessionSize),
      difficulty: _difficulty,
      confusions: confusions,
    );
    setState(() {
      _questions = questions;
      // Snapshot due-ness now, before any answer in this session moves
      // nextReviewDate — otherwise every session would look "all due" by
      // the time it ends.
      _allDueSession =
          questions.isNotEmpty && questions.every((q) => !q.entry.nextReviewDate.isAfter(now));
      _current = 0;
      _score = 0;
      _streak = 0;
      _selectedIndex = null;
      _answered = false;
      _wrongAnswers.clear();
      _newlyMastered.clear();
      _phase = _Phase.running;
    });
  }

  Future<void> _answer(int index) async {
    if (_answered) return;
    final repo = AppScope.of(context);
    final studyLog = AppScope.studyLogOf(context);
    final confusions = AppScope.quizConfusionsOf(context);
    final question = _questions[_current];
    final correct = index == question.correctIndex;
    final wasMastered = question.entry.isMastered;

    // correctCount/wrongCount still drive the Progress screen's stats;
    // the SM-2 fields drive which entries the next quiz prioritizes.
    question.entry.recordAnswer(correct: correct);
    Sm2Service.review(question.entry, correct: correct);
    await repo.save(question.entry);
    await studyLog.recordReview();
    if (!correct) {
      await confusions.recordConfusion(
        questionEntryId: question.entry.id,
        pickedEntryId: question.optionEntryIds[index],
      );
      _wrongAnswers.add(
        _WrongAnswer(
          term: question.entry.term,
          correctMeaning: question.entry.meaningMy,
          picked: question.options[index],
        ),
      );
    }
    if (!wasMastered && question.entry.isMastered) {
      _newlyMastered.add(question.entry.term);
    }

    setState(() {
      _selectedIndex = index;
      _answered = true;
      if (correct) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
    });

    await Future<void>.delayed(_advanceDelay);
    if (!mounted) return;

    setState(() {
      if (_current + 1 >= _questions.length) {
        _phase = _Phase.done;
      } else {
        _current++;
        _selectedIndex = null;
        _answered = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.idle => _IdleView(
          onStart: _start,
          difficulty: _difficulty,
          onDifficultyChanged: _onDifficultyChanged,
          sessionSize: _sessionSize,
          onSessionSizeChanged: _onSessionSizeChanged,
        ),
      _Phase.running => _QuestionView(
          question: _questions[_current],
          index: _current,
          total: _questions.length,
          streak: _streak,
          selectedIndex: _selectedIndex,
          answered: _answered,
          onSelect: _answer,
        ),
      _Phase.done => _SummaryView(
          score: _score,
          total: _questions.length,
          allDueSession: _allDueSession,
          wrongAnswers: _wrongAnswers,
          newlyMastered: _newlyMastered,
          onRetry: _start,
          onHome: () => AppScope.tabControllerOf(context).index = 0,
        ),
    };
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.onStart,
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.sessionSize,
    required this.onSessionSizeChanged,
  });

  final VoidCallback onStart;
  final QuizDifficulty difficulty;
  final ValueChanged<QuizDifficulty> onDifficultyChanged;
  final QuizSessionSize sessionSize;
  final ValueChanged<QuizSessionSize> onSessionSizeChanged;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final poolSize = repo.all().where((e) => e.meaningMy.trim().isNotEmpty).length;
    final sessionCount = poolSize >= QuizService.sessionSize ? QuizService.sessionSize : poolSize;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.hankoRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.checkmark_seal,
              color: AppColors.hankoRed,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '1回のセッションで最大 $sessionCount 問',
            style: const TextStyle(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 20),
          const Text(
            '難易度',
            style: TextStyle(color: AppColors.inkSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<QuizDifficulty>(
            groupValue: difficulty,
            thumbColor: AppColors.hankoRed,
            backgroundColor: AppColors.borderLine.withValues(alpha: 0.4),
            children: {
              for (final value in QuizDifficulty.values)
                value: _DifficultyLabel(value: value, selected: difficulty == value),
            },
            onValueChanged: (value) {
              if (value != null) onDifficultyChanged(value);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            '問題数',
            style: TextStyle(color: AppColors.inkSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<QuizSessionSize>(
            groupValue: sessionSize,
            thumbColor: AppColors.hankoRed,
            backgroundColor: AppColors.borderLine.withValues(alpha: 0.4),
            children: {
              for (final value in QuizSessionSize.values)
                value: _SessionSizeLabel(value: value, selected: sessionSize == value),
            },
            onValueChanged: (value) {
              if (value != null) onSessionSizeChanged(value);
            },
          ),
          const SizedBox(height: 20),
          CupertinoButton.filled(
            onPressed: onStart,
            child: const Text('クイズを始める'),
          ),
        ],
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.index,
    required this.total,
    required this.streak,
    required this.selectedIndex,
    required this.answered,
    required this.onSelect,
  });

  final QuizQuestion question;
  final int index;
  final int total;
  final int streak;
  final int? selectedIndex;
  final bool answered;
  final ValueChanged<int> onSelect;

  Color _backgroundFor(int i) {
    if (!answered) return AppColors.cardBackground;
    if (i == question.correctIndex) return AppColors.successGreen.withValues(alpha: 0.35);
    if (i == selectedIndex) return AppColors.errorRed.withValues(alpha: 0.35);
    return AppColors.cardBackground;
  }

  Color _borderFor(int i) {
    if (!answered) return AppColors.borderLine;
    if (i == question.correctIndex) return AppColors.successGreen;
    if (i == selectedIndex) return AppColors.errorRed;
    return AppColors.borderLine;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (streak >= 2) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.hankoRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.hankoRed.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$streak問連続正解中！',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hankoRed,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            '$index / $total',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _ProgressBar(fraction: total == 0 ? 0 : index / total),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLine),
                ),
                child: Text(
                  question.entry.term,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkPrimary,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: SpeakButton(text: question.entry.term),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _backgroundFor(i),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _borderFor(i),
                      width: answered && (i == selectedIndex || i == question.correctIndex) ? 2 : 1,
                    ),
                    boxShadow: answered
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.inkPrimary.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.paperBackground,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderLine),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          question.options[i],
                          style: const TextStyle(fontSize: 16, color: AppColors.inkPrimary),
                        ),
                      ),
                      if (answered && i == question.correctIndex)
                        const Icon(
                          CupertinoIcons.check_mark_circled_solid,
                          color: AppColors.successGreen,
                          size: 22,
                        ),
                      if (answered && i == selectedIndex && i != question.correctIndex)
                        const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: AppColors.errorRed,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Label for one segment of the 難易度 control — explicit colors (not the
/// default inherited style) so the text stays readable against the red
/// thumb when selected, matching [TypeSegmentedControl]'s pattern.
class _DifficultyLabel extends StatelessWidget {
  const _DifficultyLabel({required this.value, required this.selected});

  final QuizDifficulty value;
  final bool selected;

  static const _text = {
    QuizDifficulty.easy: 'かんたん',
    QuizDifficulty.normal: 'ふつう',
    QuizDifficulty.hard: 'むずかしい',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        _text[value]!,
        style: TextStyle(
          inherit: false,
          color: selected ? CupertinoColors.white : AppColors.inkPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Label for one segment of the 問題数 control — same explicit-color
/// pattern as [_DifficultyLabel].
class _SessionSizeLabel extends StatelessWidget {
  const _SessionSizeLabel({required this.value, required this.selected});

  final QuizSessionSize value;
  final bool selected;

  static const _text = {
    QuizSessionSize.five: '5問',
    QuizSessionSize.ten: '10問',
    QuizSessionSize.all: '全部',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        _text[value]!,
        style: TextStyle(
          inherit: false,
          color: selected ? CupertinoColors.white : AppColors.inkPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A simple Cupertino-friendly progress bar — Flutter's
/// LinearProgressIndicator is Material-only.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.score,
    required this.total,
    required this.allDueSession,
    required this.wrongAnswers,
    required this.newlyMastered,
    required this.onRetry,
    required this.onHome,
  });

  final int score;
  final int total;

  /// True when every question in the session was due for review when the
  /// session started — see [_QuizViewState._start]'s snapshot of that,
  /// taken before any answer could move an entry's nextReviewDate.
  final bool allDueSession;
  final List<_WrongAnswer> wrongAnswers;
  final List<String> newlyMastered;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final studyLog = AppScope.studyLogOf(context);
    final percent = total == 0 ? 0 : ((score / total) * 100).round();
    final daysThisWeek = studyLog.lastNDays(7).where((c) => c > 0).length;
    final streak = studyLog.currentStreak;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            allDueSession ? '今日の復習 完了' : 'お疲れさま',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.inkPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Text(
                  '$score / $total',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hankoRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '正答率 $percent%',
                  style: const TextStyle(fontSize: 15, color: AppColors.inkSecondary),
                ),
              ],
            ),
          ),
          if (newlyMastered.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'マスター済み +${newlyMastered.length}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.successGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    newlyMastered.join('、'),
                    style: const TextStyle(fontSize: 14, color: AppColors.inkPrimary),
                  ),
                ],
              ),
            ),
          ],
          if (wrongAnswers.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '見直しておきたい問題',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final wrong in wrongAnswers.take(5)) _WrongAnswerRow(wrong: wrong),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLine),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatColumn(label: '今週の復習日数', value: '$daysThisWeek / 7'),
                _StatColumn(label: '連続', value: '$streak 日'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: onRetry,
            child: const Text('もう一度'),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            onPressed: onHome,
            child: const Text(
              'ホームへ',
              style: TextStyle(color: AppColors.hankoRed),
            ),
          ),
        ],
      ),
    );
  }
}

class _WrongAnswerRow extends StatelessWidget {
  const _WrongAnswerRow({required this.wrong});

  final _WrongAnswer wrong;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wrong.term,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.inkPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '正解: ${wrong.correctMeaning}',
            style: const TextStyle(fontSize: 13, color: AppColors.successGreen),
          ),
          Text(
            '選んだ答え: ${wrong.picked}',
            style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.inkPrimary),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary)),
      ],
    );
  }
}

/// One wrong answer from a finished session, for the completion screen's
/// review list (max 5 shown — see [_SummaryView]).
class _WrongAnswer {
  const _WrongAnswer({
    required this.term,
    required this.correctMeaning,
    required this.picked,
  });

  final String term;
  final String correctMeaning;
  final String picked;
}
