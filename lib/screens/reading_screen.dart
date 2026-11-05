import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

import '../app_scope.dart';
import '../models/reading_passage.dart';
import '../services/groq_service.dart';
import '../theme/app_colors.dart';
import 'reading_detail_screen.dart';

const List<String> _levels = ['N5', 'N4', 'N3', 'N2', 'N1'];

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  String _level = 'N5';
  ReadingType _type = ReadingType.shortPassage;
  bool _generating = false;

  Future<void> _generate() async {
    final repo = AppScope.readingOf(context);

    setState(() => _generating = true);
    try {
      final result = await GroqService.generateReadingPassage(level: _level, type: _type);
      final passage = await repo.create(
        level: _level,
        type: _type,
        passage: result.passage,
        questions: result.questions,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => ReadingDetailScreen(passage: passage)),
      );
    } catch (e) {
      if (!mounted) return;
      final message =
          e is GroqServiceException ? e.message : '読解問題の生成に失敗しました。通信環境を確認してください。';
      await _showAlert('生成エラー', message);
    } finally {
      if (mounted) setState(() => _generating = false);
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

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: const Size(0, 0),
        color: selected ? AppColors.hankoRed : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        onPressed: _generating ? null : onTap,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? CupertinoColors.white : AppColors.inkPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _levelChip(String level) {
    return _chip(
      label: level,
      selected: level == _level,
      onTap: () => setState(() => _level = level),
    );
  }

  Widget _typeChip(ReadingType type) {
    final selected = type == _type;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 0),
        color: selected ? AppColors.hankoRed : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        onPressed: _generating ? null : () => setState(() => _type = type),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              type.label,
              style: TextStyle(
                color: selected ? CupertinoColors.white : AppColors.inkPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Text(
              type.chipSubtitle,
              style: TextStyle(
                color: selected
                    ? CupertinoColors.white.withValues(alpha: 0.85)
                    : AppColors.inkSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.readingOf(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text('読解'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: _levels.map(_levelChip).toList()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(children: ReadingType.values.map(_typeChip).toList()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _generating ? null : _generate,
                  child: _generating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CupertinoActivityIndicator(color: CupertinoColors.white, radius: 8),
                            SizedBox(width: 8),
                            Text('生成中…'),
                          ],
                        )
                      : const Text('新しい読解問題を生成'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<Box<ReadingPassage>>(
                valueListenable: repo.listenable(),
                builder: (context, _, __) {
                  final passages = repo.all();
                  if (passages.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'まだ読解問題がありません。\n上のボタンから生成してください。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.inkSecondary, fontSize: 15),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: passages.length,
                    separatorBuilder: (_, __) => Container(
                      margin: const EdgeInsets.only(left: 16),
                      height: 0.5,
                      color: AppColors.borderLine,
                    ),
                    itemBuilder: (context, index) {
                      final passage = passages[index];
                      final preview = passage.passage.length > 28
                          ? '${passage.passage.substring(0, 28)}…'
                          : passage.passage;
                      return CupertinoListTile(
                        title: Text(
                          '[${passage.level}・${passage.type.label}] $preview',
                          style: const TextStyle(color: AppColors.inkPrimary),
                        ),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => ReadingDetailScreen(passage: passage),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
