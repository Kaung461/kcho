import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

import '../app_scope.dart';
import '../models/diary_entry.dart';
import '../services/groq_service.dart';
import '../theme/app_colors.dart';
import '../widgets/more_menu_button.dart';

/// "Mini diary" screen: write a short Japanese sentence, get it corrected
/// and explained by AI, and review past entries. The output-practice
/// counterpart to the vocabulary/reading SRS flow elsewhere in the app.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final repo = AppScope.diaryOf(context);
    setState(() => _submitting = true);
    try {
      final result = await GroqService.reviewDiary(text);
      await repo.create(text: text, corrected: result.corrected, feedback: result.feedback);
      if (!mounted) return;
      _controller.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      final message =
          e is GroqServiceException ? e.message : '添削に失敗しました。通信環境を確認してください。';
      await _showAlert('添削エラー', message);
    } finally {
      if (mounted) setState(() => _submitting = false);
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

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.diaryOf(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text('作文'),
        trailing: MoreMenuButton(),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: CupertinoTextField(
                    controller: _controller,
                    placeholder: '今日のことを日本語で1〜3行、書いてみましょう。',
                    minLines: 2,
                    maxLines: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    style: const TextStyle(color: AppColors.inkPrimary, fontSize: 16),
                    placeholderStyle: const TextStyle(color: AppColors.inkSecondary),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLine),
                    ),
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder<Box<DiaryEntry>>(
                    valueListenable: repo.listenable(),
                    builder: (context, _, __) {
                      final entries = repo.all();
                      if (entries.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'まだ書いた文章がありません。\n上に日本語で何か書いてみましょう。',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.inkSecondary, fontSize: 15),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _DiaryCard(entry: entries[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _SubmitPill(submitting: _submitting, onPressed: _submitting ? null : _submit),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating pill that replaces the old inline "AIに添削してもらう" button —
/// always reachable at thumb height instead of scrolling away with the
/// text field.
class _SubmitPill extends StatelessWidget {
  const _SubmitPill({required this.submitting, required this.onPressed});

  final bool submitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkPrimary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: AppColors.hankoRed,
        disabledColor: AppColors.hankoRed.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          child: submitting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(color: CupertinoColors.white, radius: 8),
                    SizedBox(width: 8),
                    Text('添削中…'),
                  ],
                )
              : const Text('AIに添削してもらう'),
        ),
      ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final wasCorrected = entry.corrected.trim() != entry.text.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'あなたの文章',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            entry.text,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.inkSecondary,
              decoration: wasCorrected ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.inkSecondary,
            ),
          ),
          if (wasCorrected) ...[
            const SizedBox(height: 14),
            const Text(
              '添削後',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.successGreen),
            ),
            const SizedBox(height: 4),
            Text(
              entry.corrected,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.inkPrimary,
              ),
            ),
          ],
          if (entry.feedback.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.paperBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.lightbulb, size: 18, color: AppColors.hankoRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.feedback,
                      style: const TextStyle(fontSize: 14, color: AppColors.inkPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
