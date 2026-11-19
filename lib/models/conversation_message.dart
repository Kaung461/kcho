/// One turn in an in-memory 会話練習 session (see [ConversationScreen]).
/// Never persisted — the conversation lives only for the current app
/// session, by design (see the feature's prompt: no Hive, no cloud sync).
enum ConversationRole { user, ai }

class ConversationMessage {
  ConversationMessage({
    required this.role,
    required this.text,
    this.feedback,
  });

  final ConversationRole role;
  final String text;

  /// AI-only: a short correction of the user's previous message, or null
  /// when nothing needed fixing. Always null for [ConversationRole.user].
  final String? feedback;

  /// Myanmar translation of [text], filled in lazily when the user taps
  /// 「ミャンマー語で」 on an AI bubble. Mutable since it's requested
  /// after the message already exists.
  String? translatedMy;

  /// True once a translation was attempted and failed — shown instead of
  /// retrying automatically.
  bool translationFailed = false;
}
