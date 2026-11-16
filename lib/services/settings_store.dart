import 'package:shared_preferences/shared_preferences.dart';

/// Local-only app settings (profile name, reminder prefs), persisted with
/// shared_preferences. No backend — everything stays on-device.
class SettingsStore {
  static const _keyDisplayName = 'display_name';
  static const _keyReminderEnabled = 'reminder_enabled';
  static const _keyReminderHour = 'reminder_hour';
  static const _keyReminderMinute = 'reminder_minute';

  static const _keyGoalWordCount = 'goal_word_count';
  static const _keyQuizDifficulty = 'quiz_difficulty';
  static const _keyQuizSessionSize = 'quiz_session_size';

  static const int defaultReminderHour = 20;
  static const int defaultReminderMinute = 0;
  static const int defaultGoalWordCount = 300;

  /// 'easy' | 'normal' | 'hard' — kept as a plain string here so this store
  /// doesn't need to depend on QuizService's enum; quiz_screen.dart maps
  /// between the two.
  static const String defaultQuizDifficulty = 'hard';

  /// '5' | '10' | 'all'.
  static const String defaultQuizSessionSize = '10';

  Future<String> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDisplayName) ?? '';
  }

  Future<void> setDisplayName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, value);
  }

  Future<bool> getReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyReminderEnabled) ?? false;
  }

  Future<void> setReminderEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReminderEnabled, value);
  }

  /// Returns (hour, minute), defaulting to 20:00.
  Future<(int hour, int minute)> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_keyReminderHour) ?? defaultReminderHour;
    final minute = prefs.getInt(_keyReminderMinute) ?? defaultReminderMinute;
    return (hour, minute);
  }

  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderHour, hour);
    await prefs.setInt(_keyReminderMinute, minute);
  }

  /// Target word count shown as the "目標の進捗" bar on the Progress screen.
  Future<int> getGoalWordCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyGoalWordCount) ?? defaultGoalWordCount;
  }

  Future<void> setGoalWordCount(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGoalWordCount, value);
  }

  Future<String> getQuizDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyQuizDifficulty) ?? defaultQuizDifficulty;
  }

  Future<void> setQuizDifficulty(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQuizDifficulty, value);
  }

  Future<String> getQuizSessionSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyQuizSessionSize) ?? defaultQuizSessionSize;
  }

  Future<void> setQuizSessionSize(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQuizSessionSize, value);
  }
}
