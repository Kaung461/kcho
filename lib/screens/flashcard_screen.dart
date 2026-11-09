import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

import '../app_scope.dart';
import '../models/entry.dart';
import '../theme/app_colors.dart';
import '../widgets/speak_button.dart';
import '../widgets/type_segmented_control.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  EntryType _type = EntryType.tango;
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changeType(EntryType type) {
    setState(() {
      _type = type;
      _index = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: SizedBox(
          width: 220,
          child: TypeSegmentedControl(value: _type, onChanged: _changeType),
        ),
      ),
      child: SafeArea(
        child: ValueListenableBuilder<Box<Entry>>(
          valueListenable: repo.listenable(),
          builder: (context, _, __) {
            final entries = repo.byType(_type);
            if (entries.isEmpty) {
              return const Center(
                child: Text(
                  'カードがありません。',
                  style: TextStyle(color: AppColors.inkSecondary),
                ),
              );
            }
            final safeIndex = _index.clamp(0, entries.length - 1);
            return Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: entries.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _Flashcard(
                      key: ValueKey(entries[i].id),
                      entry: entries[i],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 4),
                  child: Text(
                    '${safeIndex + 1} / ${entries.length}',
                    style: const TextStyle(color: AppColors.inkSecondary),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Flashcard extends StatefulWidget {
  const _Flashcard({required this.entry, super.key});

  final Entry entry;

  @override
  State<_Flashcard> createState() => _FlashcardState();
}

class _FlashcardState extends State<_Flashcard> {
  bool _showBack = false;

  @override
  void didUpdateWidget(_Flashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) _showBack = false;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasReading = entry.reading != null && entry.reading!.trim().isNotEmpty;
    final speakText = entry.exampleSentence.trim().isNotEmpty
        ? entry.exampleSentence
        : entry.term;

    return GestureDetector(
      onTap: () => setState(() => _showBack = !_showBack),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Container(
              key: ValueKey(_showBack),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 260),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLine),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.inkPrimary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: SpeakButton(text: _showBack ? speakText : entry.term),
                  ),
                  Center(
                    child: _showBack
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasReading)
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.paperBackground,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    entry.reading!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.inkSecondary,
                                    ),
                                  ),
                                ),
                              if (hasReading) const SizedBox(height: 16),
                              Text(
                                entry.meaningMy,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkPrimary,
                                ),
                              ),
                              if (entry.exampleSentence.trim().isNotEmpty) ...[
                                const SizedBox(height: 18),
                                Container(width: 40, height: 1, color: AppColors.borderLine),
                                const SizedBox(height: 18),
                                Text(
                                  entry.exampleSentence,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.inkSecondary,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            entry.term,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
