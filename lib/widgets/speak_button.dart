import 'package:flutter/cupertino.dart';

import '../services/tts_service.dart';
import '../theme/app_colors.dart';

/// A small speaker icon that reads [text] aloud in Japanese when tapped.
class SpeakButton extends StatelessWidget {
  const SpeakButton({required this.text, this.size = 22, super.key});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 0),
      onPressed: () => TtsService.instance.speak(text),
      child: Icon(CupertinoIcons.speaker_2_fill, size: size, color: AppColors.hankoRed),
    );
  }
}
