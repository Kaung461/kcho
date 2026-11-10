import 'dart:convert';

import 'package:hive/hive.dart';

/// Which JLPT reading-section format to generate — chosen by the user
/// before generating (see ReadingScreen). Mirrors the real exam's five
/// categories; each carries the full instruction GroqService needs to
/// produce that format, since they differ in more than just length (e.g.
/// 情報検索 wants a flyer-style document, 統合理解 wants two passages).
enum ReadingType {
  shortPassage(
    label: '短文',
    chipSubtitle: '80〜200字・1問',
    promptInstruction: '80〜200字程度の物語文かエッセイを書くこと。'
        '本文全体のメインメッセージや筆者の考えを問う設問を1つ作ること。',
    timerMinutes: 3,
  ),
  mediumPassage(
    label: '中文',
    chipSubtitle: '350〜500字・3問',
    promptInstruction: '350〜500字程度の説明文かエッセイを書くこと。'
        '因果関係や具体的な内容、筆者の主張の流れを問う設問を3つ作ること。',
    timerMinutes: 7,
  ),
  longPassage(
    label: '長文',
    chipSubtitle: '600〜1000字・4問',
    promptInstruction: '600〜1000字程度の論説文かエッセイを書くこと。'
        '文章全体の内容展開や論理構造を問う設問を4つ作ること。',
    timerMinutes: 10,
  ),
  infoSearch(
    label: '情報検索',
    chipSubtitle: 'チラシ・お知らせ',
    promptInstruction: 'チラシ、案内文、お知らせ、パンフレットのような形式の文章を書くこと'
        '（日時・料金・条件などの具体的な情報を箇条書きなどで含めること）。'
        '文章を全部読まなくても必要な情報を素早く探せるような、実生活の場面を想定した設問を2つ作ること'
        '（例:「〇〇したい人はどれを選べばいいか」）。',
    timerMinutes: 4,
  ),
  integrated(
    label: '統合理解',
    chipSubtitle: '2つの文章を比較',
    promptInstruction: '同じテーマについて異なる立場や視点を述べた2つの短い文章を書くこと。'
        'それぞれの文章の前に「【文章A】」「【文章B】」という見出しを付け、各150字程度にすること。'
        '2つの文章の共通点・相違点やそれぞれの筆者の主張を問う設問を2つ作ること。',
    timerMinutes: 10,
  );

  const ReadingType({
    required this.label,
    required this.chipSubtitle,
    required this.promptInstruction,
    required this.timerMinutes,
  });

  /// Short Japanese label shown in the UI (短文/中文/長文/情報検索/統合理解).
  final String label;

  /// Small-print detail shown under [label] in the UI.
  final String chipSubtitle;

  /// Full instruction appended to the Groq prompt for this format.
  final String promptInstruction;

  /// Suggested exam-practice time limit, matching real JLPT pacing per
  /// passage length.
  final int timerMinutes;
}

/// One multiple-choice comprehension question about a [ReadingPassage].
class ReadingQuestion {
  ReadingQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;

  /// Why the correct choice is right AND why each wrong choice is a trap —
  /// shown after the user answers. In Myanmar, matching the app's other
  /// AI explanations.
  final String explanation;

  factory ReadingQuestion.fromJson(Map<String, dynamic> json) {
    // Groq occasionally pads the options list with a stray empty string —
    // drop blanks defensively rather than showing an empty choice button.
    final rawOptions = (json['options'] as List<dynamic>).map((e) => e as String).toList();
    final correctIndex = json['correctIndex'] as int;
    final correctValue = correctIndex < rawOptions.length ? rawOptions[correctIndex] : null;
    final options = rawOptions.where((o) => o.trim().isNotEmpty).toList();
    final fixedCorrectIndex = correctValue != null ? options.indexOf(correctValue) : correctIndex;

    return ReadingQuestion(
      question: json['question'] as String,
      options: options,
      correctIndex: fixedCorrectIndex >= 0 ? fixedCorrectIndex : correctIndex,
      explanation: (json['explanation'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };
}

/// An AI-generated JLPT reading-comprehension passage with its questions.
///
/// [questions] is stored as a single JSON-encoded string field rather than a
/// nested Hive type, to keep the hand-written adapter simple — matching
/// [Entry]'s approach of avoiding build_runner / codegen.
class ReadingPassage extends HiveObject {
  ReadingPassage({
    required this.id,
    required this.level,
    required this.type,
    required this.passage,
    required this.questions,
    required this.createdAt,
  });

  /// Stable UUID, also used as the Hive key.
  final String id;

  /// JLPT level this was generated for, e.g. "N5".
  String level;

  /// Which reading format this is (短文/中文/長文/情報検索/統合理解) — drives
  /// the practice timer's duration when reviewing this passage.
  ReadingType type;

  String passage;
  List<ReadingQuestion> questions;
  final DateTime createdAt;

  /// Used by [SyncService] to write this passage to Firestore.
  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'type': type.name,
        'passage': passage,
        'questions': questions.map((q) => q.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  /// Inverse of [toJson] — used by [SyncService] to rebuild a passage read
  /// back from Firestore.
  factory ReadingPassage.fromJson(Map<String, dynamic> json) => ReadingPassage(
        id: json['id'] as String,
        level: json['level'] as String,
        type: ReadingType.values.firstWhere(
          (t) => t.name == json['type'] as String,
          orElse: () => ReadingType.shortPassage,
        ),
        passage: json['passage'] as String,
        questions: (json['questions'] as List<dynamic>)
            .map((e) => ReadingQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Hand-written Hive adapter (keeps the project free of build_runner / codegen).
class ReadingPassageAdapter extends TypeAdapter<ReadingPassage> {
  @override
  final int typeId = 1;

  @override
  ReadingPassage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final questionsJson = jsonDecode(fields[3] as String) as List<dynamic>;
    // Field 5 (type) is absent on records written before the JLPT reading
    // formats were added — fall back to shortPassage for old data.
    final typeName = fields[5] as String?;
    final type = ReadingType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => ReadingType.shortPassage,
    );
    return ReadingPassage(
      id: fields[0] as String,
      level: fields[1] as String,
      passage: fields[2] as String,
      questions: questionsJson
          .map((e) => ReadingQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: fields[4] as DateTime,
      type: type,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingPassage obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.level)
      ..writeByte(2)
      ..write(obj.passage)
      ..writeByte(3)
      ..write(jsonEncode(obj.questions.map((q) => q.toJson()).toList()))
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.type.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingPassageAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
