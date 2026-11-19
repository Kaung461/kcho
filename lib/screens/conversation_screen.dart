import 'package:flutter/cupertino.dart';

import '../app_scope.dart';
import '../models/conversation_message.dart';
import '../models/entry.dart';
import '../services/conversation_target_service.dart';
import '../services/groq_service.dart';
import '../theme/app_colors.dart';
import 'conversation_summary_screen.dart';

/// 会話練習: an in-memory chat with an AI conversation partner that steers
/// the user toward using today's studied words. Nothing here is persisted
/// (no Hive, no cloud sync) — closing or reloading the tab loses the
/// conversation, by design.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  bool _initialized = false;
  List<Entry> _targets = const [];
  bool _targetsAreFallback = false;

  final List<ConversationMessage> _messages = [];
  final Set<String> _usedTargetIds = {};
  bool _waitingForAi = false;
  bool _startFailed = false;
  bool _wrapUpOffered = false;
  DateTime? _lastSendAt;

  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final repo = AppScope.of(context);
    final targets = ConversationTargetService.targetsFrom(repo);
    _targets = targets.entries;
    _targetsAreFallback = targets.isFallback;
    _startConversation();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _startConversation() async {
    setState(() {
      _waitingForAi = true;
      _startFailed = false;
    });
    try {
      final result = await GroqService.conversationReply(targets: _targets, history: _messages);
      if (!mounted) return;
      setState(() {
        _messages.add(
          ConversationMessage(role: ConversationRole.ai, text: result.reply, feedback: result.feedback),
        );
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _startFailed = true);
    } finally {
      if (mounted) setState(() => _waitingForAi = false);
    }
  }

  void _markUsedTerms(String userText) {
    for (final entry in _targets) {
      if (userText.contains(entry.term)) _usedTargetIds.add(entry.id);
    }
  }

  int get _userMessageCount =>
      _messages.where((m) => m.role == ConversationRole.user).length;

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _waitingForAi) return;
    final now = DateTime.now();
    if (_lastSendAt != null && now.difference(_lastSendAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastSendAt = now;

    setState(() {
      _messages.add(ConversationMessage(role: ConversationRole.user, text: text));
      _markUsedTerms(text);
      _waitingForAi = true;
    });
    _input.clear();
    _scrollToBottom();

    try {
      final result = await GroqService.conversationReply(targets: _targets, history: _messages);
      if (!mounted) return;
      setState(() {
        _messages.add(
          ConversationMessage(role: ConversationRole.ai, text: result.reply, feedback: result.feedback),
        );
      });
      _scrollToBottom();
      if (!_wrapUpOffered && _userMessageCount >= 10) {
        _wrapUpOffered = true;
        _offerWrapUp();
      }
    } catch (e) {
      if (!mounted) return;
      // The reply never arrived — restore the text to the input so nothing
      // typed is lost, per the spec. The bubble the user already sees
      // stays (it's genuinely what they said); only the retry path changes.
      _input.text = text;
      final message =
          e is GroqServiceException ? e.message : 'うまく返事ができませんでした。もう一度送ってください。';
      await _showAlert('会話エラー', message);
    } finally {
      if (mounted) setState(() => _waitingForAi = false);
    }
  }

  Future<void> _offerWrapUp() async {
    final shouldEnd = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('そろそろ終わりますか？'),
        content: const Text('ここまでの会話をまとめて見ることができます。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('続ける'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('まとめを見る'),
          ),
        ],
      ),
    );
    if (shouldEnd ?? false) _showSummary();
  }

  Future<void> _confirmNewConversation() async {
    if (_messages.isNotEmpty) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('新しい会話を始めますか？'),
          content: const Text('今の会話は消えます。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('始める'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    _resetConversation();
  }

  void _resetConversation() {
    setState(() {
      _messages.clear();
      _usedTargetIds.clear();
      _wrapUpOffered = false;
      _startFailed = false;
    });
    _startConversation();
  }

  Future<void> _showSummary() async {
    final action = await Navigator.of(context).push<ConversationSummaryAction>(
      CupertinoPageRoute(
        builder: (_) => ConversationSummaryScreen(
          targets: _targets,
          usedTargetIds: _usedTargetIds,
          corrections: _messages
              .where((m) => m.role == ConversationRole.ai && m.feedback != null)
              .map((m) => m.feedback!)
              .toList(),
        ),
      ),
    );
    if (action == ConversationSummaryAction.restart) _resetConversation();
  }

  Future<void> _showAlert(String title, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _translate(ConversationMessage message) async {
    final translation = await GroqService.translateToMyanmar(message.text);
    if (!mounted) return;
    setState(() {
      if (translation != null) {
        message.translatedMy = translation;
      } else {
        message.translationFailed = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_targets.isNotEmpty)
          _TargetChipRow(targets: _targets, usedIds: _usedTargetIds, isFallback: _targetsAreFallback)
        else
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              '今日の単語はまだありません',
              style: TextStyle(color: AppColors.inkSecondary, fontSize: 13),
            ),
          ),
        Expanded(
          child: _startFailed && _messages.isEmpty
              ? _StartErrorView(onRetry: _startConversation)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _MessageBubble(
                    message: _messages[index],
                    onTranslate: () => _translate(_messages[index]),
                  ),
                ),
        ),
        if (_waitingForAi)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoActivityIndicator(radius: 8),
                SizedBox(width: 8),
                Text('AIが入力中…', style: TextStyle(color: AppColors.inkSecondary, fontSize: 13)),
              ],
            ),
          ),
        _InputBar(
          controller: _input,
          enabled: !_waitingForAi,
          onSend: _send,
          onNewConversation: _confirmNewConversation,
          onFinish: _messages.isEmpty ? null : _showSummary,
        ),
      ],
    );
  }
}

class _TargetChipRow extends StatelessWidget {
  const _TargetChipRow({required this.targets, required this.usedIds, required this.isFallback});

  final List<Entry> targets;
  final Set<String> usedIds;
  final bool isFallback;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            isFallback ? '最近の単語' : '今日の単語',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSecondary),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: targets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = targets[index];
              final used = usedIds.contains(entry.id);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: used ? AppColors.hankoRed : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: used ? AppColors.hankoRed : AppColors.borderLine),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (used)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(CupertinoIcons.check_mark, size: 14, color: CupertinoColors.white),
                      ),
                    Text(
                      entry.term,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: used ? CupertinoColors.white : AppColors.inkPrimary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({required this.message, required this.onTranslate});

  final ConversationMessage message;
  final Future<void> Function() onTranslate;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _translating = false;

  Future<void> _handleTranslate() async {
    setState(() => _translating = true);
    await widget.onTranslate();
    if (mounted) setState(() => _translating = false);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.role == ConversationRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.hankoRed.withValues(alpha: 0.12) : AppColors.cardBackground,
                border: Border.all(
                  color: isUser ? AppColors.hankoRed.withValues(alpha: 0.4) : AppColors.borderLine,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                message.text,
                style: const TextStyle(color: AppColors.inkPrimary, fontSize: 15, height: 1.35),
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _translating ? null : _handleTranslate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _translating
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoActivityIndicator(radius: 6),
                            SizedBox(width: 6),
                            Text('訳しています…', style: TextStyle(fontSize: 11, color: AppColors.inkSecondary)),
                          ],
                        )
                      : const Text('ミャンマー語で', style: TextStyle(fontSize: 11, color: AppColors.hankoRed)),
                ),
              ),
              if (message.translatedMy != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    message.translatedMy!,
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                  ),
                ),
              if (message.translationFailed && message.translatedMy == null)
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 2),
                  child: Text('うまく訳せませんでした', style: TextStyle(fontSize: 12, color: AppColors.errorRed)),
                ),
            ],
            if (message.feedback != null) ...[
              const SizedBox(height: 6),
              _FeedbackCard(text: message.feedback!),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatefulWidget {
  const _FeedbackCard({required this.text});

  final String text;

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.paperBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ひとこと添削',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            widget.text,
            maxLines: _expanded ? null : 2,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.inkPrimary, height: 1.3),
          ),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _expanded ? '閉じる' : 'もっと見る',
                style: const TextStyle(fontSize: 11, color: AppColors.hankoRed),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.onNewConversation,
    required this.onFinish,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onNewConversation;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLine)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onNewConversation,
                  child: const Text('新しい会話', style: TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onFinish,
                  child: const Text('おわる', style: TextStyle(fontSize: 13, color: AppColors.hankoRed)),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: controller,
                    enabled: enabled,
                    placeholder: 'メッセージを入力',
                    minLines: 1,
                    maxLines: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    style: const TextStyle(color: AppColors.inkPrimary, fontSize: 15),
                    placeholderStyle: const TextStyle(color: AppColors.inkSecondary),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLine),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.all(10),
                  color: AppColors.hankoRed,
                  disabledColor: AppColors.hankoRed.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                  onPressed: enabled ? onSend : null,
                  child: const Icon(CupertinoIcons.arrow_up, color: CupertinoColors.white, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StartErrorView extends StatelessWidget {
  const _StartErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '会話を始められませんでした。',
              style: TextStyle(color: AppColors.inkSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            CupertinoButton(onPressed: onRetry, child: const Text('もう一度試す')),
          ],
        ),
      ),
    );
  }
}
