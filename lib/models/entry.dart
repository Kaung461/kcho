import 'package:hive/hive.dart';

/// Whether an [Entry] is a vocabulary word (tango) or a grammar pattern.
enum EntryType { tango, grammar }

/// A single study item — either a vocabulary word or a grammar pattern —
/// together with its Myanmar meaning and spaced-repetition counters.
class Entry extends HiveObject {
  Entry({
    required this.id,
    required this.type,
    required this.term,
    required this.meaningMy,
    required this.exampleSentence,
    required this.createdAt,
    this.reading,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lastReviewed,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    DateTime? nextReviewDate,
    DateTime? updatedAt,
  })  : nextReviewDate = nextReviewDate ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt;

  /// Stable UUID, also used as the Hive key.
  final String id;

  EntryType type;

  /// Kanji / word for tango, or the grammar pattern for grammar.
  String term;

  /// よみかた — only meaningful for [EntryType.tango].
  String? reading;

  /// Myanmar meaning (အဓိပ္ပါယ်).
  String meaningMy;

  /// 例文 — an example sentence.
  String exampleSentence;

  int correctCount;
  int wrongCount;
  DateTime? lastReviewed;
  final DateTime createdAt;

  // --- SM-2 spaced-repetition scheduling (see Sm2Service) ---
  // Additive to correctCount/wrongCount above, not a replacement: those two
  // still drive the Progress screen's mastered/learning stats, while these
  // drive which entries the quiz should prioritize.

  /// How quickly the review interval grows after each correct answer.
  double easeFactor;

  /// Days until the next review, per the SM-2 algorithm.
  int interval;

  /// Consecutive correct answers since the last lapse.
  int repetitions;

  /// When this entry is next due for review. Defaults to "now" for new
  /// entries, so they're immediately eligible for their first quiz.
  DateTime nextReviewDate;

  /// Last local modification time — set by [EntryRepository], not by
  /// callers. Used only to break ties when [SyncService] merges the same
  /// entry id edited on two different devices (last write wins).
  DateTime updatedAt;

  bool get isTango => type == EntryType.tango;

  /// Mastered = answered correctly at least 3 times with no wrong answers.
  bool get isMastered => correctCount >= 3 && wrongCount == 0;

  /// Has been quizzed at least once but is not yet mastered.
  bool get isLearning => (correctCount + wrongCount) > 0 && !isMastered;

  /// Due for spaced-repetition review — on or before now.
  bool get isDue => !nextReviewDate.isAfter(DateTime.now());

  void recordAnswer({required bool correct}) {
    if (correct) {
      correctCount++;
    } else {
      wrongCount++;
    }
    lastReviewed = DateTime.now();
  }

  /// Plain-data representation used by Settings' "export data" feature and
  /// by [SyncService] to write this entry to Firestore.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'term': term,
        'reading': reading,
        'meaningMy': meaningMy,
        'exampleSentence': exampleSentence,
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'lastReviewed': lastReviewed?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'easeFactor': easeFactor,
        'interval': interval,
        'repetitions': repetitions,
        'nextReviewDate': nextReviewDate.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Inverse of [toJson] — used by [SyncService] to rebuild an [Entry] read
  /// back from Firestore.
  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
        id: json['id'] as String,
        type: EntryType.values.byName(json['type'] as String),
        term: json['term'] as String,
        reading: json['reading'] as String?,
        meaningMy: json['meaningMy'] as String,
        exampleSentence: json['exampleSentence'] as String,
        correctCount: json['correctCount'] as int? ?? 0,
        wrongCount: json['wrongCount'] as int? ?? 0,
        lastReviewed:
            json['lastReviewed'] == null ? null : DateTime.parse(json['lastReviewed'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
        interval: json['interval'] as int? ?? 0,
        repetitions: json['repetitions'] as int? ?? 0,
        nextReviewDate: json['nextReviewDate'] == null
            ? null
            : DateTime.parse(json['nextReviewDate'] as String),
        updatedAt:
            json['updatedAt'] == null ? null : DateTime.parse(json['updatedAt'] as String),
      );
}

/// Hand-written Hive adapter (keeps the project free of build_runner / codegen).
class EntryAdapter extends TypeAdapter<Entry> {
  @override
  final int typeId = 0;

  @override
  Entry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Entry(
      id: fields[0] as String,
      type: EntryType.values[fields[1] as int],
      term: fields[2] as String,
      reading: fields[3] as String?,
      meaningMy: fields[4] as String,
      exampleSentence: fields[5] as String,
      correctCount: fields[6] as int? ?? 0,
      wrongCount: fields[7] as int? ?? 0,
      lastReviewed: fields[8] as DateTime?,
      createdAt: fields[9] as DateTime,
      // Fields 10-13 are absent on records written before SM-2 was added;
      // fall back to the same defaults Entry's constructor uses for new
      // entries, so old data becomes immediately due like a fresh entry.
      easeFactor: fields[10] as double? ?? 2.5,
      interval: fields[11] as int? ?? 0,
      repetitions: fields[12] as int? ?? 0,
      nextReviewDate: fields[13] as DateTime?,
      // Field 14 is absent on records written before sync was added —
      // fall back to createdAt, same as the Entry constructor's default.
      updatedAt: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Entry obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type.index)
      ..writeByte(2)
      ..write(obj.term)
      ..writeByte(3)
      ..write(obj.reading)
      ..writeByte(4)
      ..write(obj.meaningMy)
      ..writeByte(5)
      ..write(obj.exampleSentence)
      ..writeByte(6)
      ..write(obj.correctCount)
      ..writeByte(7)
      ..write(obj.wrongCount)
      ..writeByte(8)
      ..write(obj.lastReviewed)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.easeFactor)
      ..writeByte(11)
      ..write(obj.interval)
      ..writeByte(12)
      ..write(obj.repetitions)
      ..writeByte(13)
      ..write(obj.nextReviewDate)
      ..writeByte(14)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntryAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
