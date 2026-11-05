import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/reading_passage.dart';

/// Thin wrapper around the Hive box that stores AI-generated reading
/// passages (see [GroqService.generateReadingPassage]).
class ReadingRepository {
  ReadingRepository(this._box);

  static const String boxName = 'reading_passages';
  static const Uuid _uuid = Uuid();

  final Box<ReadingPassage> _box;

  ValueListenable<Box<ReadingPassage>> listenable() => _box.listenable();

  /// Newest first.
  List<ReadingPassage> all() {
    final list = _box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<ReadingPassage> create({
    required String level,
    required ReadingType type,
    required String passage,
    required List<ReadingQuestion> questions,
  }) async {
    final entry = ReadingPassage(
      id: _uuid.v4(),
      level: level,
      type: type,
      passage: passage,
      questions: questions,
      createdAt: DateTime.now(),
    );
    await _box.put(entry.id, entry);
    return entry;
  }

  Future<void> delete(ReadingPassage passage) => _box.delete(passage.id);
}
