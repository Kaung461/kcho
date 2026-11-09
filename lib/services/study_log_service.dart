import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Tracks how many quiz answers were recorded on each calendar day, for the
/// Home streak strip and (later) the Progress screen's "today / all-time"
/// stats. Stored as a single `yyyy-MM-dd -> count` map in its own Hive box
/// — no custom HiveObject/typeId needed since it's just Dart primitives.
class StudyLogService {
  StudyLogService(this._box);

  static const String boxName = 'study_log';
  static const String _mapKey = 'log';

  final Box<dynamic> _box;

  ValueListenable<Box<dynamic>> listenable() => _box.listenable();

  Map<String, int> _read() {
    final raw = _box.get(_mapKey);
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key as String, value as int));
    }
    return {};
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Call whenever a quiz answer is recorded.
  Future<void> recordReview([DateTime? when]) async {
    final log = _read();
    final key = _dateKey(when ?? DateTime.now());
    log[key] = (log[key] ?? 0) + 1;
    await _box.put(_mapKey, log);
  }

  int reviewedOn(DateTime day) => _read()[_dateKey(day)] ?? 0;

  int get reviewedToday => reviewedOn(DateTime.now());

  /// Consecutive days with at least one review, ending today — or ending
  /// yesterday if today's review hasn't happened yet, so the streak
  /// doesn't appear broken before the day is over.
  int get currentStreak {
    final log = _read();
    var day = DateTime.now();
    if ((log[_dateKey(day)] ?? 0) == 0) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while ((log[_dateKey(day)] ?? 0) > 0) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Total number of distinct days with at least one review.
  int get daysStudied => _read().values.where((v) => v > 0).length;

  /// Review counts for the last [n] days (oldest first, today last).
  List<int> lastNDays(int n) {
    final log = _read();
    final now = DateTime.now();
    return [
      for (var i = n - 1; i >= 0; i--) log[_dateKey(now.subtract(Duration(days: i)))] ?? 0,
    ];
  }
}
