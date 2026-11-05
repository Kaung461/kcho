import 'package:flutter/cupertino.dart';

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
class HighlightedJapaneseText extends StatelessWidget {
  const HighlightedJapaneseText({
    required this.text,
    this.style = const TextStyle(fontSize: 17, height: 1.7, color: AppColors.inkPrimary),
    super.key,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: _buildSpans()), style: style);
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
