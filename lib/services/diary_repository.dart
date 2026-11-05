import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/diary_entry.dart';

/// Thin wrapper around the Hive box that stores diary/composition entries
/// (see [GroqService.reviewDiary]).
class DiaryRepository {
  DiaryRepository(this._box);

  static const String boxName = 'diary_entries';
  static const Uuid _uuid = Uuid();

  final Box<DiaryEntry> _box;

  ValueListenable<Box<DiaryEntry>> listenable() => _box.listenable();

  /// Newest first.
  List<DiaryEntry> all() {
    final list = _box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<DiaryEntry> create({
    required String text,
    required String corrected,
    required String feedback,
  }) async {
    final entry = DiaryEntry(
      id: _uuid.v4(),
      text: text,
      corrected: corrected,
      feedback: feedback,
      createdAt: DateTime.now(),
    );
    await _box.put(entry.id, entry);
    return entry;
  }

  Future<void> delete(DiaryEntry entry) => _box.delete(entry.id);
}
