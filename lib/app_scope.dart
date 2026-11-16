import 'package:flutter/cupertino.dart';

import 'services/diary_repository.dart';
import 'services/entry_repository.dart';
import 'services/quiz_confusion_service.dart';
import 'services/reading_repository.dart';
import 'services/study_log_service.dart';

/// Makes the shared [EntryRepository], [ReadingRepository],
/// [DiaryRepository], [StudyLogService] and [QuizConfusionService]
/// available to the whole widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.repository,
    required this.readingRepository,
    required this.diaryRepository,
    required this.studyLog,
    required this.quizConfusions,
    required this.tabController,
    required super.child,
    super.key,
  });

  final EntryRepository repository;
  final ReadingRepository readingRepository;
  final DiaryRepository diaryRepository;
  final StudyLogService studyLog;
  final QuizConfusionService quizConfusions;

  /// Shared with [RootTabs] so other screens (e.g. the quiz completion
  /// screen's ホームへ button) can switch the bottom tab programmatically.
  final CupertinoTabController tabController;

  static EntryRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.repository;
  }

  static ReadingRepository readingOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.readingRepository;
  }

  static DiaryRepository diaryOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.diaryRepository;
  }

  static StudyLogService studyLogOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.studyLog;
  }

  static QuizConfusionService quizConfusionsOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.quizConfusions;
  }

  static CupertinoTabController tabControllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.tabController;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.repository != repository ||
      oldWidget.readingRepository != readingRepository ||
      oldWidget.diaryRepository != diaryRepository ||
      oldWidget.studyLog != studyLog ||
      oldWidget.quizConfusions != quizConfusions ||
      oldWidget.tabController != tabController;
}
