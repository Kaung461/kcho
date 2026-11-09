import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import 'diary_screen.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'review_screen.dart';

/// Bottom tab bar that hosts the main sections of the app. Settings moved
/// off the tab bar into the "…" menu on every screen; Flashcards and Quiz
/// were merged into the 復習 tab (see [ReviewScreen]). 読解 isn't a tab —
/// it's reached from Home's shortcut tile, since it's just one screen with
/// no sub-navigation of its own.
class RootTabs extends StatelessWidget {
  const RootTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: AppColors.hankoRed,
        inactiveColor: AppColors.inkSecondary,
        backgroundColor: AppColors.cardBackground.withValues(alpha: 0.9),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: 'ホーム',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.rectangle_stack),
            label: '復習',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.pencil_outline),
            label: '作文',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar),
            label: '進捗',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoTabView(builder: (_) => const HomeScreen());
          case 1:
            return CupertinoTabView(builder: (_) => const ReviewScreen());
          case 2:
            return CupertinoTabView(builder: (_) => const DiaryScreen());
          case 3:
          default:
            return CupertinoTabView(builder: (_) => const ProgressScreen());
        }
      },
    );
  }
}
