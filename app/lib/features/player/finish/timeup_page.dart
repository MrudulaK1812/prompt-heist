import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/score_colors.dart';
import '../battle/game_state.dart';
import 'result_page.dart';

const _blue = Color(0xFF4285F4);

class TimeUpPage extends ConsumerStatefulWidget {
  const TimeUpPage({super.key});

  @override
  ConsumerState<TimeUpPage> createState() => _TimeUpPageState();
}

class _TimeUpPageState extends ConsumerState<TimeUpPage> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // If result:confirmed is missed, ask the server every 3 seconds.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) ref.invalidate(resultProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(resultProvider, (prev, next) {
      final d = next.value;
      if (d != null && d['status'] == 'CONFIRMED') context.go('/player/result');
    });

    final game = ref.watch(gameProvider);
    final best = game.bestScore ?? 0;
    final scored = game.prompts
        .where((p) => p.stage == PromptStage.scored)
        .length;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 38,
                      color: _blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Time's up!",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Calculating results…',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          'Your best score',
                          '$best',
                          scoreColor(best),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat('Prompts scored', '$scored', _blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How the winner is decided',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'The highest best score wins. If two players tie, '
                          'the player who reached that score first wins.',
                          style: TextStyle(height: 1.4),
                        ),
                      ],
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.accent);
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'AppMono',
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    ),
  );
}
