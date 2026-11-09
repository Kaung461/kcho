import 'dart:math';

import 'package:flutter/cupertino.dart';

import '../app_scope.dart';
import '../services/quiz_service.dart';
import '../services/sm2_service.dart';
import '../theme/app_colors.dart';
import '../widgets/speak_button.dart';

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

  _Phase _phase = _Phase.idle;
  List<QuizQuestion> _questions = [];
  int _current = 0;
  int _score = 0;
  int _streak = 0;
  int? _selectedIndex;
  bool _answered = false;

  void _start() {
    final repo = AppScope.of(context);
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
    setState(() {
      _questions = QuizService.buildSession(repo, random: _rng);
      _current = 0;
      _score = 0;
      _streak = 0;
      _selectedIndex = null;
      _answered = false;
      _phase = _Phase.running;
    });
  }

  Future<void> _answer(int index) async {
    if (_answered) return;
    final repo = AppScope.of(context);
    final studyLog = AppScope.studyLogOf(context);
    final question = _questions[_current];
    final correct = index == question.correctIndex;

    // correctCount/wrongCount still drive the Progress screen's stats;
    // the SM-2 fields drive which entries the next quiz prioritizes.
    question.entry.recordAnswer(correct: correct);
    Sm2Service.review(question.entry, correct: correct);
    await repo.save(question.entry);
    await studyLog.recordReview();

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
      _Phase.idle => _IdleView(onStart: _start),
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
          onRetry: _start,
        ),
    };
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onStart});

  final VoidCallback onStart;

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
    required this.onRetry,
  });

  final int score;
  final int total;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '結果',
            style: TextStyle(fontSize: 20, color: AppColors.inkPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            '$score / $total',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: AppColors.hankoRed,
            ),
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: onRetry,
            child: const Text('もう一度'),
          ),
        ],
      ),
    );
  }
}
