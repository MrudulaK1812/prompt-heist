import 'package:flutter/material.dart';

import '../../../shared/score_colors.dart';
import 'game_state.dart';

class PromptTile extends StatelessWidget {
  const PromptTile(this.p, {super.key, required this.onRetry});
  final PromptItem p;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, canRetry) = switch (p.stage) {
      PromptStage.submitting => ('Submitting…', false),
      PromptStage.evaluating => ('Evaluating…', false),
      PromptStage.scored => (p.feedback ?? 'Scored', false),
      PromptStage.blocked => (
        p.message ?? 'That prompt cannot be displayed. Try a different game-focused prompt.',
        false,
      ),
      PromptStage.failed => (
        p.message ?? 'We could not score that one. Please try again.',
        true,
      ),
    };

    final leading = switch (p.stage) {
      PromptStage.scored => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scoreColor(p.score ?? 0),
          shape: BoxShape.circle,
        ),
        child: Text(
          '${p.score ?? 0}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: (p.score ?? 0) >= 40 && (p.score ?? 0) < 80
                ? Colors.black87
                : Colors.white,
          ),
        ),
      ),
      PromptStage.blocked => const Icon(
        Icons.block_rounded,
        size: 32,
        color: Colors.black45,
      ),
      PromptStage.failed => const Icon(
        Icons.error_outline_rounded,
        size: 32,
        color: Color(0xFFEA4335),
      ),
      _ => const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 44, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(p.text, style: const TextStyle(color: Colors.black54)),
                  if (canRetry)
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
