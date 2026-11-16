import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/entry.dart';
import '../models/reading_passage.dart';

/// Reading/meaning/example suggested by Groq for one term.
class GroqAutoFillResult {
  GroqAutoFillResult({
    required this.reading,
    required this.meaningMy,
    required this.exampleSentence,
    this.incomplete = false,
  });

  /// Only populated for [EntryType.tango]; grammar patterns have no reading.
  final String? reading;
  final String meaningMy;
  final String exampleSentence;

  /// True when at least one field failed validation (see
  /// [GroqService._autoFillWord]) and was left blank rather than filled
  /// with a value that didn't pass its format check. Always false for
  /// [EntryType.grammar], which isn't validated — see that method's doc.
  final bool incomplete;
}

/// An AI-generated JLPT reading passage with its comprehension questions.
class GroqReadingResult {
  GroqReadingResult({required this.passage, required this.questions});

  final String passage;
  final List<ReadingQuestion> questions;
}

/// Correction and feedback on one diary/composition entry.
class GroqDiaryResult {
  GroqDiaryResult({required this.corrected, required this.feedback});

  /// Natural-Japanese correction of what the user wrote (identical to the
  /// original if there was nothing to fix).
  final String corrected;

  /// Explanation of what was wrong / why, in Myanmar.
  final String feedback;
}

/// Calls the AI features (auto-filling a new entry's fields, generating
/// JLPT reading passages, correcting diary entries) via a small
/// server-side proxy — see `worker/` — instead of calling Groq directly.
///
/// The real Groq API key lives only in that proxy, as a Cloudflare Worker
/// secret. It never ships inside this app's build. [_proxyUrl] is baked in
/// at build time via `--dart-define=AI_PROXY_URL=...` (see the GitHub
/// Actions workflow for the web build) and is not a secret — it's just the
/// proxy's public URL.
class GroqService {
  GroqService._();

  static const String _model = 'openai/gpt-oss-20b';
  static const String _proxyUrl = String.fromEnvironment('AI_PROXY_URL');
  static const String _endpoint = '$_proxyUrl/chat';

  /// Asks Groq to fill in the fields for [term]. Throws on any
  /// network/API/parse failure — callers should surface the error rather
  /// than silently leaving fields blank, since a wrong auto-fill is worse
  /// than none. [userReadingHint] — the reading the user already typed, if
  /// any — is passed to the model so it doesn't contradict it; only used
  /// for [EntryType.tango].
  static Future<GroqAutoFillResult> autoFill({
    required EntryType type,
    required String term,
    String? userReadingHint,
  }) {
    return type == EntryType.tango
        ? _autoFillWord(term: term, userReadingHint: userReadingHint)
        : _autoFillGrammar(term: term);
  }

  /// Grammar patterns have no "reading" concept and no validated output
  /// contract — the quality issue this was fixed for (偽り reading as にせ
  /// instead of いつわり, a garbled meaning) was specifically about word
  /// lookups, so this keeps its original prompt/behavior unchanged rather
  /// than retrofitting the word-specific JSON schema onto it.
  static Future<GroqAutoFillResult> _autoFillGrammar({required String term}) async {
    const multiSenseInstruction =
        '複数の意味・用法がある場合は、主なものを全て含め、それぞれの意味の前にどんな場面で'
        '使うかが一目でわかる短い日本語の文脈を（）で付けて'
        '「１）（電話で）ミャンマー語訳　２）（服を）ミャンマー語訳」のように番号を付けて区切ること。'
        '日本語の単語や例文は繰り返さず、文脈タグとミャンマー語訳だけを書くこと。'
        '意味が1つしかない場合は番号も文脈もつけずミャンマー語訳だけを書くこと。';
    final prompt = '日本語の文法パターン「$term」について、次のJSONだけを返してください。説明文は付けないこと。\n'
        '{"meaningMy": "ミャンマー語でのこの文法の意味・使い方（$multiSenseInstruction）", '
        '"exampleSentence": "そのパターンを使った自然な日本語の例文"}';

    final content = await _complete(prompt: prompt);
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw GroqServiceException('Groq からの応答を解析できませんでした。');
    }

    return GroqAutoFillResult(
      reading: null,
      meaningMy: (parsed['meaningMy'] as String?)?.trim() ?? '',
      exampleSentence: (parsed['exampleSentence'] as String?)?.trim() ?? '',
    );
  }

  static const String _wordSystemPrompt = '''
あなたは日本語教師です。ミャンマー語話者の学習者向けに、日本語の単語情報をJSONだけで返してください。説明文やコードブロックは不要です。
ルール:
- reading: ひらがなのみ。漢字・カタカナ・ローマ字は使わない。その単語の最も一般的な読み方を1つだけ。
- meaning_my: ミャンマー語のみ。日本語・英語の文字や括弧書きの補足を混ぜない。短い意味を最大3つ、「၊」で区切る。
- meaning_en: 短い英語の意味（最大3語）。
- example_ja: 自然な日本語の例文を1つ。N2以下の文法と語彙で、入力された単語をそのまま含める。
- 確信がない項目は null にする。推測で埋めない。
出力形式: {"reading":"","meaning_my":"","meaning_en":"","example_ja":""}
''';

  static const String _wordRetryNote = '前回の出力は形式が不正でした。ルールを厳守してください。';

  /// Looks up [term] with the strict, validated word-lookup prompt (Phase
  /// 1/2 of the 偽り/にせ fix): a JSON-mode call against [_wordSystemPrompt]
  /// (no `temperature` — `openai/gpt-oss-20b` is a reasoning model and
  /// rejects that parameter with a 400, which is not obvious until you
  /// actually send one), then each field is checked against its own
  /// format rule before it's allowed into [GroqAutoFillResult] — a field
  /// that fails is left null/blank rather than filled with a guess. If
  /// [reading] or [meaningMy] fails, the whole call is retried once with an
  /// extra line telling the model its last output was malformed; after
  /// that, whatever still doesn't validate is simply left blank (see
  /// [GroqAutoFillResult.incomplete]) rather than retried again.
  static Future<GroqAutoFillResult> _autoFillWord({
    required String term,
    String? userReadingHint,
  }) async {
    Future<Map<String, dynamic>> callOnce({String? retryNote}) async {
      final lines = <String>[term];
      if (userReadingHint != null && userReadingHint.isNotEmpty) {
        lines.add('ユーザー入力の読み: $userReadingHint');
      }
      if (retryNote != null) lines.add(retryNote);

      final content = await _complete(
        prompt: lines.join('\n'),
        system: _wordSystemPrompt,
      );
      try {
        return jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        throw GroqServiceException('Groq からの応答を解析できませんでした。');
      }
    }

    var parsed = await callOnce();
    var reading = _validReading(parsed['reading']);
    var meaningMy = _validMeaningMy(parsed['meaning_my']);

    if (reading == null || meaningMy == null) {
      parsed = await callOnce(retryNote: _wordRetryNote);
      reading = _validReading(parsed['reading']);
      meaningMy = _validMeaningMy(parsed['meaning_my']);
    }

    final exampleJa = _validExampleJa(parsed['example_ja'], term);
    // meaning_en is part of the model's output contract (asking for it
    // alongside meaning_my seems to help the model's own consistency) but
    // isn't surfaced anywhere: there's no field for it on Entry/the
    // add-entry form, and the existing Hive adapter must stay untouched
    // (see this fix's constraints) — so it's validated and discarded.
    _validMeaningEn(parsed['meaning_en']);

    final incomplete = reading == null || meaningMy == null || exampleJa == null;

    return GroqAutoFillResult(
      reading: reading,
      meaningMy: meaningMy ?? '',
      exampleSentence: exampleJa ?? '',
      incomplete: incomplete,
    );
  }

  static final RegExp _hiragana = RegExp('^[ぁ-んー]+\$');
  static final RegExp _hiraganaKatakanaKanji = RegExp('[぀-ヿ一-鿿]');
  static final RegExp _myanmarChar = RegExp('[က-႟]');
  static final RegExp _fullWidthBrackets = RegExp('[（）「」『』]');
  static final RegExp _asciiTextOnly = RegExp(r"^[A-Za-z0-9 .,;:'!?()\-]+$");

  /// `^[ぁ-んー]+$` — hiragana only, per the word-lookup prompt's own rule.
  static String? _validReading(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return _hiragana.hasMatch(trimmed) ? trimmed : null;
  }

  /// At least one Myanmar character, and none of: hiragana, katakana,
  /// kanji, or full-width brackets (the exact contamination the 偽り bug
  /// report showed — a stray "（会話で）" mixed into the meaning).
  static String? _validMeaningMy(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!_myanmarChar.hasMatch(trimmed)) return null;
    if (_hiraganaKatakanaKanji.hasMatch(trimmed)) return null;
    if (_fullWidthBrackets.hasMatch(trimmed)) return null;
    return trimmed;
  }

  /// ASCII letters/digits/spaces/punctuation only.
  static String? _validMeaningEn(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return _asciiTextOnly.hasMatch(trimmed) ? trimmed : null;
  }

  /// Must actually contain the word it's supposed to be an example of.
  static String? _validExampleJa(Object? value, String term) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.contains(term) ? trimmed : null;
  }

  /// Generates one JLPT [level] (e.g. "N5") reading passage with multiple
  /// comprehension questions, in the requested [type] (see [ReadingType] —
  /// mirrors the exam's own 短文/中文/長文/情報検索/統合理解 categories).
  /// Uses a lower reasoning effort than [autoFill] since a passage +
  /// questions is a much larger response — this keeps token usage low
  /// enough to stay comfortably inside Groq's free-tier per-minute limit
  /// even for [ReadingType.longPassage].
  static Future<GroqReadingResult> generateReadingPassage({
    required String level,
    required ReadingType type,
  }) async {
    final prompt = 'JLPT $levelレベルの読解問題を1つ作成してください。'
        '${type.promptInstruction}'
        '$levelの学習者が読める語彙・文法だけを使うこと。'
        '各設問に4つの選択肢と、正解のインデックス（0始まり）を付けること。'
        'さらに各設問に、正解の理由だけでなく、残り3つの不正解の選択肢がそれぞれなぜ間違い・'
        'ひっかけなのかも含めた解説を、学習者が分かるようミャンマー語で書くこと'
        '（例:「選択肢2は、本文では『時々』と書かれているのに『いつも』となっているため不正解です」）。'
        '次のJSON形式だけを返してください。説明文は付けないこと。\n'
        '{"passage": "日本語の文章", "questions": ['
        '{"question": "設問文", "options": ["選択肢1","選択肢2","選択肢3","選択肢4"], "correctIndex": 0, '
        '"explanation": "ミャンマー語での解説（正解の理由＋他の選択肢がなぜ間違いか）"}'
        ']}';

    final content = await _complete(prompt: prompt, reasoningEffort: 'low');
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw GroqServiceException('Groq からの応答を解析できませんでした。');
    }

    try {
      final passage = parsed['passage'] as String;
      final questions = (parsed['questions'] as List<dynamic>)
          .map((e) => ReadingQuestion.fromJson(e as Map<String, dynamic>))
          .toList();
      return GroqReadingResult(passage: passage, questions: questions);
    } catch (_) {
      throw GroqServiceException('Groq からの応答を解析できませんでした。');
    }
  }

  /// Corrects and gives feedback on one short Japanese composition the user
  /// wrote — the "output" counterpart to [autoFill]'s vocabulary lookups.
  static Future<GroqDiaryResult> reviewDiary(String text) async {
    final prompt = '次の日本語の文章は、日本語学習者が書いたものです。'
        '文章:「$text」\n'
        '自然な日本語に添削してください（間違いがなければそのまま返すこと）。'
        'また、どこをどう直したか、なぜそうした方がいいかを、学習者が分かるようミャンマー語で'
        '優しく説明してください。'
        '次のJSON形式だけを返してください。説明文は付けないこと。\n'
        '{"corrected": "添削後の自然な日本語の文章", "feedback": "ミャンマー語でのフィードバック"}';

    final content = await _complete(prompt: prompt, reasoningEffort: 'low');
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw GroqServiceException('Groq からの応答を解析できませんでした。');
    }

    return GroqDiaryResult(
      corrected: (parsed['corrected'] as String?)?.trim() ?? text,
      feedback: (parsed['feedback'] as String?)?.trim() ?? '',
    );
  }

  /// Shared request/response handling for all AI features: posts [prompt]
  /// as the sole user message and returns the assistant's raw JSON-string
  /// content. Throws [GroqServiceException] on any HTTP or shape failure
  /// (including a missing build-time key); callers still need to
  /// `jsonDecode` the returned string themselves since each feature expects
  /// a different JSON shape back.
  static Future<String> _complete({
    required String prompt,
    String? system,
    String? reasoningEffort,
  }) async {
    if (_proxyUrl.isEmpty) {
      throw GroqServiceException(
        'AI機能は現在利用できません（ビルドにプロキシのURLが設定されていません）。',
      );
    }

    // Identifies the caller to the proxy for future use (e.g. per-user rate
    // limiting) — the proxy does not verify this token yet.
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              if (idToken != null) 'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'model': _model,
              'response_format': {'type': 'json_object'},
              if (reasoningEffort != null) 'reasoning_effort': reasoningEffort,
              'messages': [
                if (system != null) {'role': 'system', 'content': system},
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw GroqServiceException('AIの応答がありませんでした。時間をおいてもう一度お試しください。');
    } catch (_) {
      throw GroqServiceException('通信エラーが発生しました。ネットワーク環境を確認してください。');
    }

    if (response.statusCode == 429) {
      throw GroqServiceException('AIの利用が混み合っています。少し待ってからもう一度お試しください。');
    }
    if (response.statusCode != 200) {
      throw GroqServiceException(
        'サーバーがエラーを返しました (${response.statusCode})。',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw GroqServiceException('Groq からの応答を解析できませんでした。');
    }

    try {
      final choices = body['choices'] as List<dynamic>;
      final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
      return message['content'] as String;
    } catch (_) {
      throw GroqServiceException('Groq からの応答を解析できませんでした。');
    }
  }
}

/// A user-facing error from [GroqService] — the message is already in
/// Japanese and safe to show directly in an alert.
class GroqServiceException implements Exception {
  GroqServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
