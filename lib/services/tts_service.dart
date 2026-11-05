import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around on-device text-to-speech, always speaking Japanese.
/// Uses the platform's built-in voices — free, offline-capable, no API key.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _tts.setLanguage('ja-JP');
    await _tts.setSpeechRate(0.45);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInitialized();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
