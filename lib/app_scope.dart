import 'package:flutter/widgets.dart';

import 'services/diary_repository.dart';
import 'services/entry_repository.dart';
import 'services/reading_repository.dart';
import 'services/study_log_service.dart';

/// Makes the shared [EntryRepository], [ReadingRepository],
/// [DiaryRepository] and [StudyLogService] available to the whole widget
/// tree.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.repository,
    required this.readingRepository,
    required this.diaryRepository,
    required this.studyLog,
    required super.child,
    super.key,
  });

  final EntryRepository repository;
  final ReadingRepository readingRepository;
  final DiaryRepository diaryRepository;
  final StudyLogService studyLog;

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

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.repository != repository ||
      oldWidget.readingRepository != readingRepository ||
      oldWidget.diaryRepository != diaryRepository ||
      oldWidget.studyLog != studyLog;
}
