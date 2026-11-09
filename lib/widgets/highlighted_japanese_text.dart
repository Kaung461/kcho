import 'package:flutter/cupertino.dart';
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

/// Renders [text] with known connector words (しかし、つまり、そのため…)
/// highlighted, so the logical structure of a passage is easier to follow.
///
/// The text is selectable; when [onAddToVocabulary] is given, selecting any
/// text adds a "単語帳に追加" action to the selection menu, alongside the
/// usual copy/select-all — the shortcut for "saw an unknown word while
/// reading, want to look it up and remember it later" (see ReadingDetail,
/// which wires this to AddEntryScreen's AI auto-fill).
class HighlightedJapaneseText extends StatelessWidget {
  const HighlightedJapaneseText({
    required this.text,
    this.style = const TextStyle(fontSize: 17, height: 1.7, color: AppColors.inkPrimary),
    this.onAddToVocabulary,
    super.key,
  });

  final String text;
  final TextStyle style;
  final ValueChanged<String>? onAddToVocabulary;

  @override
  Widget build(BuildContext context) {
    return material.SelectableText.rich(
      TextSpan(children: _buildSpans()),
      style: style,
      contextMenuBuilder: onAddToVocabulary == null
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
                      onAddToVocabulary!(selected);
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

  List<TextSpan> _buildSpans() {
    final spans = <TextSpan>[];
    var cursor = 0;

    while (cursor < text.length) {
      String? matched;
      var matchIndex = -1;

      for (final connector in _connectors) {
        final index = text.indexOf(connector, cursor);
        if (index != -1 && (matchIndex == -1 || index < matchIndex)) {
          matchIndex = index;
          matched = connector;
        }
      }

      if (matched == null) {
        spans.add(TextSpan(text: text.substring(cursor)));
        break;
      }

      if (matchIndex > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, matchIndex)));
      }
      spans.add(
        TextSpan(
          text: matched,
          style: const TextStyle(color: AppColors.hankoRed, fontWeight: FontWeight.w700),
        ),
      );
      cursor = matchIndex + matched.length;
    }

    return spans;
  }
}
