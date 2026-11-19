import '../models/entry.dart';
import 'entry_repository.dart';

/// Up to 8 entries to steer 会話練習 toward, plus whether they come from
/// "studied today" or a fallback.
class ConversationTargets {
  ConversationTargets({required this.entries, required this.isFallback});

  final List<Entry> entries;

  /// True when nothing was studied today and [entries] falls back to the
  /// most recently added/reviewed entries instead — the UI labels this
  /// case 「最近の単語」 rather than implying it's specifically "today's".
  final bool isFallback;

  bool get isEmpty => entries.isEmpty;
}

/// Picks which entries today's 会話練習 session should try to work into the
/// conversation.
class ConversationTargetService {
  ConversationTargetService._();

  static const int maxTargets = 8;
  static const int fallbackCount = 5;

  /// "Studied today" = [Entry.lastReviewed] falls on today's calendar date
  /// — set by the quiz (see `quiz_screen.dart`'s `recordAnswer` call) each
  /// time an answer is recorded. Flashcard-only review doesn't touch this
  /// field, so a day spent only on flashcards falls through to the
  /// fallback below, same as a day with no review at all.
  ///
  /// Falls back to the 5 most recently added-or-reviewed entries (across
  /// both types equally) when nothing was reviewed today, so the feature
  /// still has something to work with on a fresh install or a quiz-free
  /// day.
  static ConversationTargets targetsFrom(EntryRepository repo) {
    final all = repo.all();
    final today = DateTime.now();
    bool isToday(DateTime? d) =>
        d != null && d.year == today.year && d.month == today.month && d.day == today.day;

    final studiedToday = all.where((e) => isToday(e.lastReviewed)).toList()
      ..sort((a, b) => b.lastReviewed!.compareTo(a.lastReviewed!));
    if (studiedToday.isNotEmpty) {
      return ConversationTargets(
        entries: studiedToday.take(maxTargets).toList(),
        isFallback: false,
      );
    }

    final byRecency = [...all]..sort((a, b) {
        final aTime = a.lastReviewed ?? a.createdAt;
        final bTime = b.lastReviewed ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
    return ConversationTargets(
      entries: byRecency.take(fallbackCount).toList(),
      isFallback: true,
    );
  }
}
