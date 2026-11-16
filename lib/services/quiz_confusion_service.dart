import 'package:hive/hive.dart';

/// Tracks, per quiz question entry id, which OTHER entries' meanings the
/// user has mistakenly picked instead, and how many times — used by
/// [QuizService] to pick increasingly confusable wrong-choice distractors
/// on the むずかしい difficulty.
///
/// Stored as plain `Map<String, int>` values (wrongEntryId -> times chosen)
/// keyed by the question entry's id, in its own Hive box — same approach as
/// [StudyLogService]'s `date -> count` map, no custom HiveObject/typeId
/// needed.
class QuizConfusionService {
  QuizConfusionService(this._box);

  static const String boxName = 'quiz_confusions';
  static const int _maxPerEntry = 10;

  final Box<dynamic> _box;

  /// wrongEntryId -> times chosen by mistake when [questionEntryId] was
  /// asked, most frequent first.
  Map<String, int> confusionsFor(String questionEntryId) {
    final raw = _box.get(questionEntryId);
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key as String, value as int));
    }
    return {};
  }

  /// Call when [questionEntryId] was answered wrongly by picking the
  /// meaning that actually belongs to [pickedEntryId].
  Future<void> recordConfusion({
    required String questionEntryId,
    required String pickedEntryId,
  }) async {
    final map = confusionsFor(questionEntryId);
    map[pickedEntryId] = (map[pickedEntryId] ?? 0) + 1;

    // Cap at the 10 most-frequent entries so this can't grow without limit.
    final capped = Map<String, int>.fromEntries(
      (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(_maxPerEntry),
    );
    await _box.put(questionEntryId, capped);
  }

  /// Removes [deletedEntryId] from this history entirely — both as a
  /// question (its own row) and as a picked distractor (inside every other
  /// row) — so deleting an entry doesn't leave dangling ids behind.
  Future<void> forgetEntry(String deletedEntryId) async {
    await _box.delete(deletedEntryId);
    for (final key in _box.keys.cast<String>().toList()) {
      final map = confusionsFor(key);
      if (map.remove(deletedEntryId) != null) {
        await _box.put(key, map);
      }
    }
  }
}
