import 'package:flutter/cupertino.dart';

import '../models/reading_passage.dart';
import '../theme/app_colors.dart';
import '../widgets/speak_button.dart';

/// Shows one [ReadingPassage]: the passage text, then each comprehension
/// question with 4 tappable choices. Answers lock in immediately (like the
/// Quiz screen) with correct/wrong color feedback; a running score shows
/// once every question has been answered.
class ReadingDetailScreen extends StatefulWidget {
  const ReadingDetailScreen({required this.passage, super.key});

  final ReadingPassage passage;

  @override
  State<ReadingDetailScreen> createState() => _ReadingDetailScreenState();
}

class _ReadingDetailScreenState extends State<ReadingDetailScreen> {
  final Map<int, int> _answers = {};

  void _select(int questionIndex, int optionIndex) {
    if (_answers.containsKey(questionIndex)) return;
    setState(() => _answers[questionIndex] = optionIndex);
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.passage.questions;
    final answeredCount = _answers.length;
    final correctCount =
        _answers.entries.where((e) => e.value == questions[e.key].correctIndex).length;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text('読解 — ${widget.passage.level}'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 44, 20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLine),
                  ),
                  child: Text(
                    widget.passage.passage,
                    style: const TextStyle(fontSize: 17, height: 1.7, color: AppColors.inkPrimary),
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
            if (answeredCount == questions.length && questions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '結果: $correctCount / ${questions.length}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hankoRed,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
      ],
    );
  }
}
