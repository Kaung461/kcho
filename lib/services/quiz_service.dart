import 'dart:math';

import '../models/entry.dart';
import 'entry_repository.dart';
import 'quiz_confusion_service.dart';

/// One quiz question: a term plus its shuffled 4-choice Myanmar-meaning
/// options, which index is correct, and which entry each option's meaning
/// actually came from (needed to record confusions — see
/// [QuizConfusionService] — when the user picks a wrong one).
class QuizQuestion {
  QuizQuestion({
    required this.entry,
    required this.options,
    required this.optionEntryIds,
    required this.correctIndex,
  });

  final Entry entry;
  final List<String> options;

  /// Parallel to [options]: the id of the entry each option's meaning text
  /// was taken from (the question's own id at [correctIndex]).
  final List<String> optionEntryIds;
  final int correctIndex;
}

/// How wrong-choice distractors are picked — see [QuizService._buildOptions].
enum QuizDifficulty { easy, normal, hard }

/// Builds quiz sessions.
///
/// Selection is prioritized by spaced-repetition due date (see
/// [Entry.nextReviewDate], updated by `Sm2Service`): entries that are
/// overdue for review fill the session first, most-overdue first, since
/// those are the ones about to be forgotten. If that doesn't fill the
/// session, remaining slots are filled with entries that aren't due yet,
/// soonest-due first. This priority order is unaffected by [questionCount]
/// or [difficulty] — both only change which/how-many questions are taken
/// from this same prioritized list and how their distractors are chosen.
class QuizService {
  QuizService._();

  static const int sessionSize = 50;

  static List<QuizQuestion> buildSession(
    EntryRepository repo, {
    Random? random,
    int questionCount = sessionSize,
    QuizDifficulty difficulty = QuizDifficulty.hard,
    QuizConfusionService? confusions,
  }) {
    final rng = random ?? Random();
    final pool = repo.all().where((e) => e.meaningMy.trim().isNotEmpty).toList();
    if (pool.isEmpty) return [];

    final now = DateTime.now();
    final due = pool.where((e) => !e.nextReviewDate.isAfter(now)).toList()
      ..sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate));
    final notDue = pool.where((e) => e.nextReviewDate.isAfter(now)).toList()
      ..sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate));

    final prioritized = [...due, ...notDue];
    final cap = min(sessionSize, questionCount);
    final take = min(cap, prioritized.length);
    // Selection order is due-priority; presentation order within the
    // session is shuffled so the quiz doesn't visibly run "most overdue
    // first, then least overdue".
    final chosen = prioritized.take(take).toList()..shuffle(rng);

    return chosen.map((entry) {
      final optionPairs = _buildOptions(entry, pool, difficulty, confusions, rng);
      final options = optionPairs.map((p) => p.$1).toList();
      final optionEntryIds = optionPairs.map((p) => p.$2).toList();
      return QuizQuestion(
        entry: entry,
        options: options,
        optionEntryIds: optionEntryIds,
        correctIndex: optionEntryIds.indexOf(entry.id),
      );
    }).toList();
  }

  /// Returns 4 (meaning text, source entry id) pairs: the question's own
  /// correct pair plus up to 3 wrong-choice distractors, shuffled together.
  ///
  /// Distractor priority for [QuizDifficulty.normal]/[QuizDifficulty.hard]
  /// (never repeating a choice and never including the correct answer):
  /// 1. (hard only) Past confusions — entries the user has previously
  ///    picked by mistake for this exact question, most-frequent first.
  /// 2. Same type ([Entry.type]) and similar shape — ranked by: shares at
  ///    least one Kanji character with the question's term; similar
  ///    reading length; both written in kana only. ("Same part of speech"
  ///    from the original spec is skipped — Entry has no such field.)
  /// 3. Fallback: random entries of the same type.
  /// 4. Last resort: random from all entries (only reached if there
  ///    genuinely aren't enough same-type entries).
  /// [QuizDifficulty.easy] skips straight to a random pick from the whole
  /// pool (the original behaviour).
  static List<(String, String)> _buildOptions(
    Entry entry,
    List<Entry> pool,
    QuizDifficulty difficulty,
    QuizConfusionService? confusions,
    Random rng,
  ) {
    final correctText = entry.meaningMy.trim();
    final usedTexts = <String>{correctText};
    final chosen = <Entry>[];

    void tryAdd(Entry candidate) {
      if (chosen.length >= 3) return;
      if (candidate.id == entry.id) return;
      final text = candidate.meaningMy.trim();
      if (text.isEmpty || usedTexts.contains(text)) return;
      usedTexts.add(text);
      chosen.add(candidate);
    }

    if (difficulty == QuizDifficulty.easy) {
      final shuffled = pool.where((e) => e.id != entry.id).toList()..shuffle(rng);
      for (final c in shuffled) {
        tryAdd(c);
      }
    } else {
      if (difficulty == QuizDifficulty.hard && confusions != null) {
        final history = confusions.confusionsFor(entry.id).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final h in history) {
          if (chosen.length >= 3) break;
          for (final candidate in pool) {
            if (candidate.id == h.key) {
              tryAdd(candidate);
              break;
            }
          }
        }
      }

      final sameType = pool.where((e) => e.id != entry.id && e.type == entry.type).toList();
      for (final c in _rankBySimilarity(entry, sameType, rng)) {
        tryAdd(c);
      }

      final sameTypeShuffled = sameType.toList()..shuffle(rng);
      for (final c in sameTypeShuffled) {
        tryAdd(c);
      }

      final allShuffled = pool.where((e) => e.id != entry.id).toList()..shuffle(rng);
      for (final c in allShuffled) {
        tryAdd(c);
      }
    }

    final pairs = <(String, String)>[
      (correctText, entry.id),
      for (final c in chosen) (c.meaningMy.trim(), c.id),
    ]..shuffle(rng);
    return pairs;
  }

  /// Ranks [candidates] by how confusable they look next to [question],
  /// highest first; ties broken randomly (a one-time random key per
  /// candidate, computed before sorting, keeps the sort itself a plain
  /// stable comparison rather than calling `rng` from inside it).
  static List<Entry> _rankBySimilarity(Entry question, List<Entry> candidates, Random rng) {
    final scored = candidates.map((c) => (_similarityScore(question, c), rng.nextDouble(), c)).toList()
      ..sort((a, b) {
        final byScore = b.$1.compareTo(a.$1);
        if (byScore != 0) return byScore;
        return a.$2.compareTo(b.$2);
      });
    return scored.map((t) => t.$3).toList();
  }

  static final RegExp _kanjiChar = RegExp('[一-鿿]');
  static final RegExp _kanaOnly = RegExp(r'^[぀-ヿーー]+$');

  static int _similarityScore(Entry question, Entry candidate) {
    var score = 0;
    if (_sharesKanji(question.term, candidate.term)) score += 4;
    final qReading = question.reading;
    final cReading = candidate.reading;
    if (qReading != null &&
        qReading.isNotEmpty &&
        cReading != null &&
        cReading.isNotEmpty &&
        (qReading.length - cReading.length).abs() <= 1) {
      score += 2;
    }
    if (_kanaOnly.hasMatch(question.term) && _kanaOnly.hasMatch(candidate.term)) score += 1;
    return score;
  }

  static bool _sharesKanji(String a, String b) {
    final aKanji = a.runes.map(String.fromCharCode).where(_kanjiChar.hasMatch).toSet();
    if (aKanji.isEmpty) return false;
    return b.runes.map(String.fromCharCode).any(aKanji.contains);
  }
}
