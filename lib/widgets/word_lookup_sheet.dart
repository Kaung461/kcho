import 'package:flutter/cupertino.dart';

import '../app_scope.dart';
import '../models/entry.dart';
import '../screens/add_entry_screen.dart';
import '../services/groq_service.dart';
import '../theme/app_colors.dart';

/// Inline "looked up a word while reading" popup — shown over the reading
/// screen via [showCupertinoModalPopup] so looking up (and saving) several
/// words never requires leaving the passage. See [HighlightedJapaneseText].
class WordLookupSheet extends StatefulWidget {
  const WordLookupSheet({required this.term, super.key});

  final String term;

  @override
  State<WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends State<WordLookupSheet> {
  late final Future<GroqAutoFillResult> _future;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _future = GroqService.autoFill(type: EntryType.tango, term: widget.term);
  }

  Future<void> _save(GroqAutoFillResult result) async {
    final repo = AppScope.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    await repo.create(
      type: EntryType.tango,
      term: widget.term,
      reading: result.reading,
      meaningMy: result.meaningMy,
      exampleSentence: result.exampleSentence,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    navigator.pop();
  }

  void _editFurther() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      CupertinoPageRoute<void>(
        builder: (_) => AddEntryScreen(initialType: EntryType.tango, initialTerm: widget.term),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: CupertinoPopupSurface(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FutureBuilder<GroqAutoFillResult>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return _LoadingBody(term: widget.term);
                }
                if (snapshot.hasError) {
                  return _ErrorBody(term: widget.term, onEdit: _editFurther);
                }
                return _ResultBody(
                  term: widget.term,
                  result: snapshot.data!,
                  saving: _saving,
                  saved: _saved,
                  onSave: () => _save(snapshot.data!),
                  onEdit: _editFurther,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TermHeader extends StatelessWidget {
  const _TermHeader({required this.term, this.reading});

  final String term;
  final String? reading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          term,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.inkPrimary,
          ),
        ),
        if (reading != null && reading!.trim().isNotEmpty) ...[
          const SizedBox(width: 10),
          Text(
            reading!,
            style: const TextStyle(fontSize: 14, color: AppColors.inkSecondary),
          ),
        ],
      ],
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.term});

  final String term;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TermHeader(term: term),
        const SizedBox(height: 18),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoActivityIndicator(radius: 9),
                SizedBox(width: 10),
                Text(
                  'AIが意味を調べています…',
                  style: TextStyle(color: AppColors.inkSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.term, required this.onEdit});

  final String term;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TermHeader(term: term),
        const SizedBox(height: 12),
        const Text(
          'AI補完に失敗しました。通信環境を確認するか、手動で登録してください。',
          style: TextStyle(color: AppColors.errorRed, fontSize: 14),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: AppColors.hankoRed,
            borderRadius: BorderRadius.circular(10),
            onPressed: onEdit,
            child: const Text(
              '手動で登録',
              style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.term,
    required this.result,
    required this.saving,
    required this.saved,
    required this.onSave,
    required this.onEdit,
  });

  final String term;
  final GroqAutoFillResult result;
  final bool saving;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TermHeader(term: term, reading: result.reading),
        const SizedBox(height: 12),
        Text(
          result.meaningMy,
          style: const TextStyle(fontSize: 16, color: AppColors.inkPrimary, height: 1.4),
        ),
        if (result.exampleSentence.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paperBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              result.exampleSentence,
              style: const TextStyle(fontSize: 14, color: AppColors.inkSecondary, height: 1.4),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: saved ? null : onEdit,
                child: const Text('詳しく編集', style: TextStyle(color: AppColors.inkSecondary)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: saved ? AppColors.successGreen : AppColors.hankoRed,
                borderRadius: BorderRadius.circular(10),
                onPressed: saved || saving ? null : onSave,
                child: saving
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white, radius: 9)
                    : Text(
                        saved ? '✓ 追加しました' : '復習に追加',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
