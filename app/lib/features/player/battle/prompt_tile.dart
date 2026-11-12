import 'package:flutter/material.dart';

import '../../../shared/score_colors.dart';
import 'game_state.dart';

const _red = Color(0xFFEA4335);

class PromptTile extends StatelessWidget {
  const PromptTile(
    this.p, {
    super.key,
    required this.onRetry,
    required this.onEdit,
  });
  final PromptItem p;
  final VoidCallback onRetry; // failed: send again
  final VoidCallback onEdit; // blocked: put the text back in the input

  @override
  Widget build(BuildContext context) {
    final title = switch (p.stage) {
      PromptStage.submitting => 'Submitting…',
      PromptStage.evaluating => 'Evaluating…',
      PromptStage.scored => p.feedback ?? 'Scored',
      PromptStage.blocked => p.message ?? 'That prompt cannot be displayed. Try a different game-focused prompt.',
      PromptStage.failed =>
        p.message ?? 'We could not score that one. Please try again.',
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
        size: 30,
        color: Colors.black45,
      ),
      PromptStage.failed => const Icon(
        Icons.refresh_rounded,
        size: 30,
        color: _red,
      ),
      _ => const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    };

    final (bg, border) = switch (p.stage) {
      PromptStage.failed => (
        _red.withValues(alpha: 0.05),
        _red.withValues(alpha: 0.35),
      ),
      PromptStage.blocked => (const Color(0xFFF4F4F4), Colors.black12),
      _ => (Colors.white, Colors.black12),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
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
                  if (p.stage == PromptStage.failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ),
                  if (p.stage == PromptStage.blocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton(
                        onPressed: onEdit,
                        child: const Text('Edit prompt'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
