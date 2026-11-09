import 'package:flutter/cupertino.dart';

import '../app_scope.dart';
import '../models/entry.dart';
import '../services/groq_service.dart';
import '../theme/app_colors.dart';
import '../widgets/type_segmented_control.dart';

/// Add a new entry, or edit / delete an existing one when [existing] is given.
class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({
    this.existing,
    this.initialType = EntryType.tango,
    this.initialTerm,
    super.key,
  });

  final Entry? existing;
  final EntryType initialType;

  /// Pre-fills the term field — used when jumping here from a word selected
  /// while reading (see ReadingDetailScreen).
  final String? initialTerm;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  late final TextEditingController _term;
  late final TextEditingController _reading;
  late final TextEditingController _meaning;
  late final TextEditingController _example;
  late EntryType _type;

  bool _isAutoFilling = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType;
    _term = TextEditingController(text: e?.term ?? widget.initialTerm ?? '');
    _reading = TextEditingController(text: e?.reading ?? '');
    _meaning = TextEditingController(text: e?.meaningMy ?? '');
    _example = TextEditingController(text: e?.exampleSentence ?? '');
  }

  @override
  void dispose() {
    _term.dispose();
    _reading.dispose();
    _meaning.dispose();
    _example.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_term.text.trim().isEmpty || _meaning.text.trim().isEmpty) {
      await _showAlert('入力してください', '漢字/パターンとミャンマー語の意味は必須です。');
      return;
    }

    final repo = AppScope.of(context);
    final navigator = Navigator.of(context);

    final existing = widget.existing;
    if (existing == null) {
      await repo.create(
        type: _type,
        term: _term.text,
        reading: _type == EntryType.tango ? _reading.text : null,
        meaningMy: _meaning.text,
        exampleSentence: _example.text,
      );
    } else {
      existing
        ..type = _type
        ..term = _term.text.trim()
        ..reading = _type == EntryType.tango && _reading.text.trim().isNotEmpty
            ? _reading.text.trim()
            : null
        ..meaningMy = _meaning.text.trim()
        ..exampleSentence = _example.text.trim();
      await repo.save(existing);
    }
    navigator.pop();
  }

  Future<void> _autoFill() async {
    final term = _term.text.trim();
    if (term.isEmpty) {
      await _showAlert(
        '入力してください',
        '先に「${_type == EntryType.tango ? '漢字 / 語' : 'パターン'}」を入力してください。',
      );
      return;
    }

    setState(() => _isAutoFilling = true);
    try {
      final result = await GroqService.autoFill(type: _type, term: term);
      if (!mounted) return;
      setState(() {
        if (_type == EntryType.tango && (result.reading ?? '').isNotEmpty) {
          _reading.text = result.reading!;
        }
        _meaning.text = result.meaningMy;
        _example.text = result.exampleSentence;
      });
    } catch (e) {
      if (!mounted) return;
      final message =
          e is GroqServiceException ? e.message : 'AI補完に失敗しました。通信環境を確認してください。';
      await _showAlert('AI補完エラー', message);
    } finally {
      if (mounted) setState(() => _isAutoFilling = false);
    }
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

  Future<void> _confirmDelete() async {
    final repo = AppScope.of(context);
    final navigator = Navigator.of(context);
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('この登録を削除します。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (shouldDelete ?? false) {
      await repo.delete(widget.existing!);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTango = _type == EntryType.tango;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(_isEditing ? '編集' : '新規登録'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TypeSegmentedControl(
                value: _type,
                onChanged: (value) => setState(() => _type = value),
              ),
            ),
            const SizedBox(height: 24),
            _FieldLabel(isTango ? '漢字 / 語' : 'パターン'),
            _FieldBox(
              controller: _term,
              placeholder: isTango ? '例: 勉強' : '例: 〜たほうがいい',
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isAutoFilling ? null : _autoFill,
                child: _isAutoFilling
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoActivityIndicator(radius: 8),
                          SizedBox(width: 8),
                          Text(
                            'AIが生成中…',
                            style: TextStyle(color: AppColors.inkSecondary, fontSize: 14),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.sparkles, size: 16, color: AppColors.hankoRed),
                          SizedBox(width: 6),
                          Text(
                            'AIで自動補完',
                            style: TextStyle(color: AppColors.hankoRed, fontSize: 14),
                          ),
                        ],
                      ),
              ),
            ),
            if (isTango) ...[
              const SizedBox(height: 16),
              const _FieldLabel('よみかた'),
              _FieldBox(controller: _reading, placeholder: 'べんきょう'),
            ],
            const SizedBox(height: 20),
            const _FieldLabel('ミャンマー語の意味'),
            _FieldBox(
              controller: _meaning,
              placeholder: 'အဓိပ္ပါယ်',
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            const _FieldLabel('例文'),
            _FieldBox(
              controller: _example,
              placeholder: '例文を入力',
              minLines: 1,
              maxLines: 4,
            ),
            if (_isEditing) ...[
              const SizedBox(height: 24),
              Center(
                child: CupertinoButton(
                  onPressed: _confirmDelete,
                  child: const Text(
                    '削除',
                    style: TextStyle(color: AppColors.errorRed),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Small caption above a [_FieldBox], styled as a notebook label.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 18, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSecondary,
        ),
      ),
    );
  }
}

/// A single-field "paper card" input: cardBackground fill, borderLine
/// border, 8px rounded corners.
class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.controller,
    this.placeholder,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String? placeholder;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        minLines: minLines,
        maxLines: maxLines,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        style: const TextStyle(color: AppColors.inkPrimary, fontSize: 16),
        placeholderStyle: const TextStyle(color: AppColors.inkSecondary),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLine),
        ),
      ),
    );
  }
}
