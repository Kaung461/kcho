import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../models/reading_passage.dart';
import '../theme/app_colors.dart';
import '../widgets/highlighted_japanese_text.dart';
import '../widgets/speak_button.dart';
import '../widgets/word_lookup_sheet.dart';

/// Shows one [ReadingPassage]: a question preview (to practice "read the
/// questions first"), an exam-style countdown timer, the passage text with
/// connector words highlighted, then each comprehension question with 4
/// tappable choices. Answers lock in immediately with correct/wrong color
/// feedback plus an explanation of every choice; once all questions are
/// answered, a reading-speed (字/分) stat shows alongside the score.
class ReadingDetailScreen extends StatefulWidget {
  const ReadingDetailScreen({required this.passage, super.key});

  final ReadingPassage passage;

  @override
  State<ReadingDetailScreen> createState() => _ReadingDetailScreenState();
}

class _ReadingDetailScreenState extends State<ReadingDetailScreen> {
  final Map<int, int> _answers = {};
  late final DateTime _startTime;
  late int _remainingSeconds;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _remainingSeconds = widget.passage.type.timerMinutes * 60;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        _ticker?.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _select(int questionIndex, int optionIndex) {
    if (_answers.containsKey(questionIndex)) return;
    setState(() => _answers[questionIndex] = optionIndex);
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _lookUpWord(String term) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => WordLookupSheet(term: term),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.passage.questions;
    final answeredCount = _answers.length;
    final allAnswered = answeredCount == questions.length && questions.isNotEmpty;
    final correctCount =
        _answers.entries.where((e) => e.value == questions[e.key].correctIndex).length;
    final timeUp = _remainingSeconds <= 0;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text('読解 — ${widget.passage.level}・${widget.passage.type.label}'),
        trailing: Text(
          timeUp ? '⏰ 時間切れ' : _formatTimer(_remainingSeconds),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: timeUp ? AppColors.errorRed : AppColors.inkSecondary,
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (questions.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.paperBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '先に設問を確認してから、本文を読みましょう',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < questions.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Q${i + 1}. ${questions[i].question}',
                          style: const TextStyle(fontSize: 14, color: AppColors.inkPrimary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 44, 20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLine),
                  ),
                  child: HighlightedJapaneseText(
                    text: widget.passage.passage,
                    onAddToVocabulary: _lookUpWord,
                    onWordTap: _lookUpWord,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: SpeakButton(text: widget.passage.passage),
                ),
              ],
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < questions.length; i++) ...[
              _QuestionCard(
                index: i,
                question: questions[i],
                selectedIndex: _answers[i],
                onSelect: (optionIndex) => _select(i, optionIndex),
              ),
              const SizedBox(height: 16),
            ],
            if (allAnswered) ...[
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    Text(
                      '結果: $correctCount / ${questions.length}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.hankoRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '読む速さ: ${_charsPerMinute()}字/分',
                      style: const TextStyle(fontSize: 14, color: AppColors.inkSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _charsPerMinute() {
    final elapsedMinutes = DateTime.now().difference(_startTime).inSeconds / 60;
    if (elapsedMinutes <= 0) return widget.passage.passage.length;
    return (widget.passage.passage.length / elapsedMinutes).round();
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int index;
  final ReadingQuestion question;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  bool get _answered => selectedIndex != null;

  Color _backgroundFor(int i) {
    if (!_answered) return AppColors.cardBackground;
    if (i == question.correctIndex) return AppColors.successGreen.withValues(alpha: 0.25);
    if (i == selectedIndex) return AppColors.errorRed.withValues(alpha: 0.25);
    return AppColors.cardBackground;
  }

  Color _borderFor(int i) {
    if (!_answered) return AppColors.borderLine;
    if (i == question.correctIndex) return AppColors.successGreen;
    if (i == selectedIndex) return AppColors.errorRed;
    return AppColors.borderLine;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Q${index + 1}. ${question.question}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.inkPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: _backgroundFor(i),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderFor(i)),
                ),
                child: Text(
                  question.options[i],
                  style: const TextStyle(fontSize: 15, color: AppColors.inkPrimary),
                ),
              ),
            ),
          ),
        if (_answered && question.explanation.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paperBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLine),
            ),
            child: Text(
              question.explanation,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary, height: 1.5),
            ),
          ),
      ],
    );
  }
}
