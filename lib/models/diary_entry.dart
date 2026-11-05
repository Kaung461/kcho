import 'package:hive/hive.dart';

/// One short Japanese composition the user wrote, plus the AI's correction
/// and feedback (see [GroqService.reviewDiary]) — the "output" side of
/// learning, alongside the SRS-driven Entry/quiz flow.
class DiaryEntry extends HiveObject {
  DiaryEntry({
    required this.id,
    required this.text,
    required this.corrected,
    required this.feedback,
    required this.createdAt,
  });

  /// Stable UUID, also used as the Hive key.
  final String id;

  /// What the user originally wrote.
  final String text;

  /// AI-corrected version of [text] (identical to it if there was nothing
  /// to fix).
  final String corrected;

  /// AI explanation of what was wrong / why, in Myanmar — matches the
  /// Myanmar-first explanations used elsewhere (see GroqService.autoFill).
  final String feedback;

  final DateTime createdAt;
}

/// Hand-written Hive adapter (keeps the project free of build_runner / codegen).
class DiaryEntryAdapter extends TypeAdapter<DiaryEntry> {
  @override
  final int typeId = 2;

  @override
  DiaryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiaryEntry(
      id: fields[0] as String,
      text: fields[1] as String,
      corrected: fields[2] as String,
      feedback: fields[3] as String,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DiaryEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.corrected)
      ..writeByte(3)
      ..write(obj.feedback)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryEntryAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
