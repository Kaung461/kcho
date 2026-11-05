import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import 'diary_screen.dart';
import 'flashcard_screen.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'quiz_screen.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';

/// Bottom tab bar that hosts the main sections of the app.
class RootTabs extends StatelessWidget {
  const RootTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: AppColors.hankoRed,
        inactiveColor: AppColors.inkSecondary,
        backgroundColor: AppColors.cardBackground,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.rectangle_stack),
            label: 'Flashcards',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.checkmark_circle),
            label: 'Quiz',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_text_search),
            label: '読解',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.pencil_outline),
            label: '作文',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoTabView(builder: (_) => const HomeScreen());
          case 1:
            return CupertinoTabView(builder: (_) => const FlashcardScreen());
          case 2:
            return CupertinoTabView(builder: (_) => const QuizScreen());
          case 3:
            return CupertinoTabView(builder: (_) => const ReadingScreen());
          case 4:
            return CupertinoTabView(builder: (_) => const DiaryScreen());
          case 5:
            return CupertinoTabView(builder: (_) => const ProgressScreen());
          case 6:
          default:
            return CupertinoTabView(builder: (_) => const SettingsScreen());
        }
      },
    );
  }
}
