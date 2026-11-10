import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/entry.dart';

/// Thin wrapper around the Hive box that stores every [Entry].
class EntryRepository {
  EntryRepository(this._box);

  static const String boxName = 'entries';
  static const Uuid _uuid = Uuid();

  final Box<Entry> _box;

  /// Rebuilds listeners whenever the box changes.
  ValueListenable<Box<Entry>> listenable() => _box.listenable();

  List<Entry> all() => _box.values.toList(growable: false);

  /// Total number of entries across both types.
  int get totalCount => _box.length;

  /// Entries of one [type], newest first.
  List<Entry> byType(EntryType type) {
    final list = _box.values.where((e) => e.type == type).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int countOfType(EntryType type) => _box.values.where((e) => e.type == type).length;

  Future<Entry> create({
    required EntryType type,
    required String term,
    required String meaningMy,
    required String exampleSentence,
    String? reading,
  }) async {
    final now = DateTime.now();
    final entry = Entry(
      id: _uuid.v4(),
      type: type,
      term: term.trim(),
      reading: reading?.trim().isEmpty ?? true ? null : reading!.trim(),
      meaningMy: meaningMy.trim(),
      exampleSentence: exampleSentence.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _box.put(entry.id, entry);
    return entry;
  }

  /// Stamps [Entry.updatedAt] so [SyncService] can tell which device's copy
  /// of an entry is newer when merging.
  Future<void> save(Entry entry) {
    entry.updatedAt = DateTime.now();
    return _box.put(entry.id, entry);
  }

  Future<void> delete(Entry entry) => _box.delete(entry.id);

  /// Seeds a few sample entries the first time the app is opened so the
  /// flashcard and quiz screens are not empty.
  Future<void> seedIfEmpty() async {
    if (_box.isNotEmpty) return;
    final now = DateTime.now();
    final samples = <Entry>[
      Entry(
        id: _uuid.v4(),
        type: EntryType.tango,
        term: '勉強',
        reading: 'べんきょう',
        meaningMy: 'စာလေ့လာခြင်း / လေ့ကျင့်ခြင်း',
        exampleSentence: '毎日日本語を勉強しています。',
        createdAt: now,
      ),
      Entry(
        id: _uuid.v4(),
        type: EntryType.tango,
        term: '約束',
        reading: 'やくそく',
        meaningMy: 'ကတိ / ချိန်းဆိုမှု',
        exampleSentence: '友達と会う約束をしました。',
        createdAt: now,
      ),
      Entry(
        id: _uuid.v4(),
        type: EntryType.tango,
        term: '影響',
        reading: 'えいきょう',
        meaningMy: 'သက်ရောက်မှု / လွှမ်းမိုးမှု',
        exampleSentence: '天気は気分に影響を与える。',
        createdAt: now,
      ),
      Entry(
        id: _uuid.v4(),
        type: EntryType.tango,
        term: '経験',
        reading: 'けいけん',
        meaningMy: 'အတွေ့အကြုံ',
        exampleSentence: '海外で働いた経験があります。',
        createdAt: now,
      ),
      Entry(
        id: _uuid.v4(),
        type: EntryType.grammar,
        term: '〜たほうがいい',
        meaningMy: '〜လုပ်တာ ပိုကောင်းတယ် (အကြံပြုချက်)',
        exampleSentence: '早く寝たほうがいいですよ。',
        createdAt: now,
      ),
      Entry(
        id: _uuid.v4(),
        type: EntryType.grammar,
        term: '〜なければならない',
        meaningMy: '〜မလုပ်မဖြစ် လုပ်ရမယ်',
        exampleSentence: '明日までにレポートを出さなければならない。',
        createdAt: now,
      ),
      Entry(
        id: _uuid.v4(),
        type: EntryType.grammar,
        term: '〜ようになる',
        meaningMy: '〜ဖြစ်လာသည် / တတ်လာသည် (အခြေအနေပြောင်းလဲမှု)',
        exampleSentence: '練習して、泳げるようになりました。',
        createdAt: now,
      ),
    ];
    await _box.putAll({for (final e in samples) e.id: e});
  }
}
