import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../widgets/more_menu_button.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

enum _ReviewMode { card, quiz }

/// 復習 tab: merges the Flashcard and Quiz screens behind a
/// カード/クイズ segmented control. Both bodies are kept alive in an
/// IndexedStack so switching back and forth doesn't lose progress.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  _ReviewMode _mode = _ReviewMode.card;

  Widget _label(String text, {required bool selected}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          inherit: false,
          color: selected ? CupertinoColors.white : AppColors.inkPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: SizedBox(
          width: 200,
          child: CupertinoSlidingSegmentedControl<_ReviewMode>(
            groupValue: _mode,
            thumbColor: AppColors.hankoRed,
            backgroundColor: AppColors.borderLine.withValues(alpha: 0.5),
            onValueChanged: (value) {
              if (value != null) setState(() => _mode = value);
            },
            children: {
              _ReviewMode.card: _label('カード', selected: _mode == _ReviewMode.card),
              _ReviewMode.quiz: _label('クイズ', selected: _mode == _ReviewMode.quiz),
            },
          ),
        ),
        trailing: const MoreMenuButton(),
      ),
      child: SafeArea(
        child: IndexedStack(
          index: _mode == _ReviewMode.card ? 0 : 1,
          children: const [
            FlashcardView(),
            QuizView(),
          ],
        ),
      ),
    );
  }
}
