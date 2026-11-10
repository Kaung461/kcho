import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
// SelectableText / AdaptiveTextSelectionToolbar only exist in Material;
// prefixed to avoid clashing with this Cupertino-only app's other widgets.
import 'package:flutter/material.dart' as material;

import '../theme/app_colors.dart';

/// Common JLPT connector words worth calling out while reading — mostly
/// contrast/cause-effect/summary connectors that carry the logical
/// structure of a passage.
const List<String> _connectors = [
  'しかし',
  'しかも',
  'ところが',
  'けれども',
  'だから',
  'そのため',
  'したがって',
  'つまり',
  '一方',
  'なぜなら',
  'それに',
  'さらに',
  'また',
  'そして',
  'すると',
  'そこで',
  'ただし',
  'もちろん',
  'たとえば',
  'このように',
];

/// Kanji compounds (情報化, 経済成長…) are what readers usually need to look
/// up, and — unlike hiragana-only words or particles — can be found without
/// real word segmentation: a maximal run of Kanji is almost always one word.
final RegExp _kanjiRun = RegExp('[一-鿿々]+');

enum _MatchKind { connector, kanji }

class _Match {
  const _Match(this.start, this.end, this.kind);

  final int start;
  final int end;
  final _MatchKind kind;
}

/// Renders [text] with known connector words (しかし、つまり、そのため…)
/// highlighted, so the logical structure of a passage is easier to follow.
///
/// Two ways to look up an unknown word, both wired (via [ReadingDetailScreen])
/// to [WordLookupSheet] so looking a word up never navigates away from the
/// passage:
/// - Tap a Kanji compound directly ([onWordTap]) — no selection needed, since
///   a maximal Kanji run is almost always one word.
/// - Drag-select anything else (okurigana, hiragana-only words, phrases) and
///   pick "単語帳に追加" from the selection menu ([onAddToVocabulary]).
class HighlightedJapaneseText extends StatefulWidget {
  const HighlightedJapaneseText({
    required this.text,
    this.style = const TextStyle(fontSize: 17, height: 1.7, color: AppColors.inkPrimary),
    this.onAddToVocabulary,
    this.onWordTap,
    super.key,
  });

  final String text;
  final TextStyle style;
  final ValueChanged<String>? onAddToVocabulary;
  final ValueChanged<String>? onWordTap;

  @override
  State<HighlightedJapaneseText> createState() => _HighlightedJapaneseTextState();
}

class _HighlightedJapaneseTextState extends State<HighlightedJapaneseText> {
  // _buildSpans() disposes and recreates these on every build, so they never
  // outlive the TextSpan tree that references them.
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return material.SelectableText.rich(
      TextSpan(children: _buildSpans()),
      style: widget.style,
      contextMenuBuilder: widget.onAddToVocabulary == null
          ? null
          : (context, editableTextState) {
              final value = editableTextState.textEditingValue;
              final selected = value.selection.textInside(value.text).trim();
              final buttonItems = editableTextState.contextMenuButtonItems.toList();
              if (selected.isNotEmpty) {
                buttonItems.insert(
                  0,
                  ContextMenuButtonItem(
                    label: '単語帳に追加',
                    onPressed: () {
                      editableTextState.hideToolbar();
                      widget.onAddToVocabulary!(selected);
                    },
                  ),
                );
              }
              return material.AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: buttonItems,
              );
            },
    );
  }

  List<InlineSpan> _buildSpans() {
    final text = widget.text;
    final matches = <_Match>[];

    for (final connector in _connectors) {
      var searchFrom = 0;
      while (true) {
        final index = text.indexOf(connector, searchFrom);
        if (index == -1) break;
        matches.add(_Match(index, index + connector.length, _MatchKind.connector));
        searchFrom = index + connector.length;
      }
    }

    for (final m in _kanjiRun.allMatches(text)) {
      matches.add(_Match(m.start, m.end, _MatchKind.kanji));
    }

    // Connectors win ties so a kanji-containing connector (e.g. 一方) is
    // highlighted as a connector rather than treated as a tappable word.
    matches.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return a.kind == _MatchKind.connector ? -1 : 1;
    });

    _disposeRecognizers();

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start < cursor) continue; // overlaps a span already claimed
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      final chunk = text.substring(m.start, m.end);
      if (m.kind == _MatchKind.connector) {
        spans.add(
          TextSpan(
            text: chunk,
            style: const TextStyle(color: AppColors.hankoRed, fontWeight: FontWeight.w700),
          ),
        );
      } else {
        TapGestureRecognizer? recognizer;
        final onWordTap = widget.onWordTap;
        if (onWordTap != null) {
          recognizer = TapGestureRecognizer()..onTap = () => onWordTap(chunk);
          _recognizers.add(recognizer);
        }
        spans.add(
          TextSpan(
            text: chunk,
            style: onWordTap == null
                ? null
                : const TextStyle(
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: AppColors.inkSecondary,
                  ),
            recognizer: recognizer,
          ),
        );
      }
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}
