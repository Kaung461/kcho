import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diary_entry.dart';
import '../models/entry.dart';
import '../models/reading_passage.dart';
import 'auth_service.dart';

/// Mirrors the local Hive boxes to Cloud Firestore under `users/{uid}/...`,
/// so the same signed-in account sees the same data on every device. Hive
/// stays the single source of truth for every screen — this runs entirely
/// in the background and never touches the UI.
///
/// Local writes flow out via [Box.watch] (local -> cloud); remote writes
/// flow in via Firestore snapshot listeners (cloud -> local). A write coming
/// down from the cloud is applied only if it actually differs from what's
/// already stored locally — that's what stops the obvious ping-pong loop
/// (apply remote -> box.watch fires -> push to cloud -> snapshot fires ->
/// apply remote -> ...) at the source: a no-op Hive write never fires
/// `watch()`, so there's nothing left to push back up.
class SyncService {
  SyncService({
    required Box<Entry> entryBox,
    required Box<ReadingPassage> readingBox,
    required Box<DiaryEntry> diaryBox,
    required Box<dynamic> studyLogBox,
  })  : _entryBox = entryBox,
        _readingBox = readingBox,
        _diaryBox = diaryBox,
        _studyLogBox = studyLogBox;

  final Box<Entry> _entryBox;
  final Box<ReadingPassage> _readingBox;
  final Box<DiaryEntry> _diaryBox;
  final Box<dynamic> _studyLogBox;
  static const String _studyLogMapKey = 'log';

  StreamSubscription<User?>? _authSub;
  final List<StreamSubscription<dynamic>> _activeSubs = [];

  /// Starts watching auth state; call once from main().
  void start() {
    _authSub = AuthService.instance.authStateChanges().listen((user) {
      _stopSyncing();
      if (user != null) {
        _startSyncing(user.uid);
      }
    });
  }

  void dispose() {
    _authSub?.cancel();
    _stopSyncing();
  }

  void _stopSyncing() {
    for (final sub in _activeSubs) {
      sub.cancel();
    }
    _activeSubs.clear();
  }

  Future<void> _startSyncing(String uid) async {
    final usersRoot = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      await _bootstrapIfNeeded(uid, usersRoot);
    } catch (_) {
      // Offline, or Firestore not enabled yet on the Firebase project — the
      // live mirroring below still attaches and will catch up once
      // connectivity/Firestore becomes available.
    }

    _watchLocalEntries(usersRoot);
    _watchLocalReading(usersRoot);
    _watchLocalDiary(usersRoot);
    _watchLocalStudyLog(usersRoot);

    _listenRemoteEntries(usersRoot);
    _listenRemoteReading(usersRoot);
    _listenRemoteDiary(usersRoot);
    _listenRemoteStudyLog(usersRoot);
  }

  // ---- local -> cloud ----

  void _watchLocalEntries(DocumentReference<Map<String, dynamic>> usersRoot) {
    final col = usersRoot.collection('entries');
    _activeSubs.add(
      _entryBox.watch().listen((event) {
        final key = event.key as String;
        if (event.deleted) {
          col.doc(key).delete().ignore();
        } else {
          final entry = _entryBox.get(key);
          if (entry != null) col.doc(key).set(entry.toJson()).ignore();
        }
      }, onError: (_) {},),
    );
  }

  void _watchLocalReading(DocumentReference<Map<String, dynamic>> usersRoot) {
    final col = usersRoot.collection('readingPassages');
    _activeSubs.add(
      _readingBox.watch().listen((event) {
        final key = event.key as String;
        if (event.deleted) {
          col.doc(key).delete().ignore();
        } else {
          final passage = _readingBox.get(key);
          if (passage != null) col.doc(key).set(passage.toJson()).ignore();
        }
      }, onError: (_) {},),
    );
  }

  void _watchLocalDiary(DocumentReference<Map<String, dynamic>> usersRoot) {
    final col = usersRoot.collection('diaryEntries');
    _activeSubs.add(
      _diaryBox.watch().listen((event) {
        final key = event.key as String;
        if (event.deleted) {
          col.doc(key).delete().ignore();
        } else {
          final entry = _diaryBox.get(key);
          if (entry != null) col.doc(key).set(entry.toJson()).ignore();
        }
      }, onError: (_) {},),
    );
  }

  void _watchLocalStudyLog(DocumentReference<Map<String, dynamic>> usersRoot) {
    final doc = usersRoot.collection('sync').doc('studyLog');
    _activeSubs.add(
      _studyLogBox.watch(key: _studyLogMapKey).listen((_) {
        doc.set(_readStudyLog()).ignore();
      }, onError: (_) {},),
    );
  }

  // ---- cloud -> local ----

  void _listenRemoteEntries(DocumentReference<Map<String, dynamic>> usersRoot) {
    _activeSubs.add(
      usersRoot.collection('entries').snapshots().listen((snap) {
        for (final change in snap.docChanges) {
          final id = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            if (_entryBox.containsKey(id)) _entryBox.delete(id);
            continue;
          }
          final data = change.doc.data();
          if (data == null) continue;
          final remote = Entry.fromJson(data);
          final local = _entryBox.get(id);
          if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
            _entryBox.put(id, remote);
          }
          // Else local is same-or-newer — skip (this is the loop-breaker).
        }
      }, onError: (_) {},),
    );
  }

  void _listenRemoteReading(DocumentReference<Map<String, dynamic>> usersRoot) {
    _activeSubs.add(
      usersRoot.collection('readingPassages').snapshots().listen((snap) {
        for (final change in snap.docChanges) {
          final id = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            if (_readingBox.containsKey(id)) _readingBox.delete(id);
            continue;
          }
          if (_readingBox.containsKey(id)) continue; // immutable once created
          final data = change.doc.data();
          if (data == null) continue;
          _readingBox.put(id, ReadingPassage.fromJson(data));
        }
      }, onError: (_) {},),
    );
  }

  void _listenRemoteDiary(DocumentReference<Map<String, dynamic>> usersRoot) {
    _activeSubs.add(
      usersRoot.collection('diaryEntries').snapshots().listen((snap) {
        for (final change in snap.docChanges) {
          final id = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            if (_diaryBox.containsKey(id)) _diaryBox.delete(id);
            continue;
          }
          if (_diaryBox.containsKey(id)) continue; // immutable once created
          final data = change.doc.data();
          if (data == null) continue;
          _diaryBox.put(id, DiaryEntry.fromJson(data));
        }
      }, onError: (_) {},),
    );
  }

  void _listenRemoteStudyLog(DocumentReference<Map<String, dynamic>> usersRoot) {
    final doc = usersRoot.collection('sync').doc('studyLog');
    _activeSubs.add(
      doc.snapshots().listen((snap) {
        final data = snap.data();
        if (data == null) return;
        final remote = data.map((k, v) => MapEntry(k, v as int));
        if (!_mapsEqual(remote, _readStudyLog())) {
          _studyLogBox.put(_studyLogMapKey, remote);
        }
      }, onError: (_) {},),
    );
  }

  Map<String, int> _readStudyLog() {
    final raw = _studyLogBox.get(_studyLogMapKey);
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key as String, value as int));
    }
    return {};
  }

  bool _mapsEqual(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  // ---- one-time bootstrap merge ----

  /// Reconciles whatever this device and the cloud each already accumulated
  /// before sync existed. Runs once per signed-in account per browser —
  /// tracked by a local flag — then live mirroring (above) takes over for
  /// everything after.
  Future<void> _bootstrapIfNeeded(
    String uid,
    DocumentReference<Map<String, dynamic>> usersRoot,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final flagKey = 'synced_bootstrap_$uid';
    if (prefs.getBool(flagKey) ?? false) return;

    await _bootstrapEntries(usersRoot);
    await _bootstrapUnionOnly<ReadingPassage>(
      usersRoot.collection('readingPassages'),
      _readingBox,
      ReadingPassage.fromJson,
      (p) => p.toJson(),
    );
    await _bootstrapUnionOnly<DiaryEntry>(
      usersRoot.collection('diaryEntries'),
      _diaryBox,
      DiaryEntry.fromJson,
      (e) => e.toJson(),
    );
    await _bootstrapStudyLog(usersRoot);

    await prefs.setBool(flagKey, true);
  }

  /// `Entry` can be edited/reviewed independently on two devices (quiz
  /// answers, SM-2 fields), so an id present on both sides is resolved by
  /// `updatedAt` (newer wins) rather than a plain union.
  Future<void> _bootstrapEntries(DocumentReference<Map<String, dynamic>> usersRoot) async {
    final col = usersRoot.collection('entries');
    final remoteDocs = await col.get();
    final remoteById = {for (final d in remoteDocs.docs) d.id: d.data()};

    for (final entry in remoteById.entries) {
      final remote = Entry.fromJson(entry.value);
      final local = _entryBox.get(entry.key);
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await _entryBox.put(entry.key, remote);
      } else if (local.updatedAt.isAfter(remote.updatedAt)) {
        await col.doc(entry.key).set(local.toJson());
      }
    }
    for (final key in _entryBox.keys.cast<String>()) {
      if (!remoteById.containsKey(key)) {
        final local = _entryBox.get(key);
        if (local != null) await col.doc(key).set(local.toJson());
      }
    }
  }

  /// Shared bootstrap for the two collections (reading passages, diary
  /// entries) that are never edited after creation — a plain union by id,
  /// no newer-wins comparison needed.
  Future<void> _bootstrapUnionOnly<T>(
    CollectionReference<Map<String, dynamic>> col,
    Box<T> box,
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final remoteDocs = await col.get();
    final remoteIds = remoteDocs.docs.map((d) => d.id).toSet();
    for (final doc in remoteDocs.docs) {
      if (!box.containsKey(doc.id)) {
        await box.put(doc.id, fromJson(doc.data()));
      }
    }
    for (final key in box.keys.cast<String>()) {
      if (!remoteIds.contains(key)) {
        final value = box.get(key);
        if (value != null) await col.doc(key).set(toJson(value));
      }
    }
  }

  /// Both sides independently accumulated real study history before sync
  /// existed, so merging by summing each day recovers true total activity
  /// instead of discarding one side. Safe to do only once, since this runs
  /// behind the same bootstrap-once guard as the rest of this method.
  Future<void> _bootstrapStudyLog(DocumentReference<Map<String, dynamic>> usersRoot) async {
    final doc = usersRoot.collection('sync').doc('studyLog');
    final snap = await doc.get();
    final remote = snap.data()?.map((k, v) => MapEntry(k, v as int)) ?? <String, int>{};
    final local = _readStudyLog();

    final merged = <String, int>{
      for (final key in {...remote.keys, ...local.keys}) key: (remote[key] ?? 0) + (local[key] ?? 0),
    };
    await _studyLogBox.put(_studyLogMapKey, merged);
    await doc.set(merged);
  }
}
