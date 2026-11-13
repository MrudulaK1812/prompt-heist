import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audience_state.dart';

const _blue = Color(0xFF4285F4);
const _red = Color(0xFFEA4335);
const _yellow = Color(0xFFFBBC05);
const _green = Color(0xFF34A853);

class AudiencePage extends ConsumerWidget {
  const AudiencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(audienceProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        // Fixed 1920x1080 stage scaled to any screen: 1080p, 4K, no scroll.
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1920,
            height: 1080,
            child: Stack(
              children: [
                Positioned.fill(child: _screenFor(a)),
                if (!a.connected)
                  Positioned(
                    top: 24,
                    right: 32,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _yellow,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Reconnecting…',
                        style: TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _screenFor(AudienceState a) {
    if (!a.ready) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    switch (a.phase) {
      case 'LOBBY':
        return _big('Joining…', _blue); // FE-20 replaces
      case 'PLAYING':
        return _big('Battle', _red); // FE-21 replaces
      case 'RESULT_PENDING':
      case 'RESULTS':
        return _big('Results', _green); // later
      default:
        return _big('Prompt Heist', _yellow); // idle, FE-20 replaces
    }
  }

  Widget _big(String text, Color c) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 160, height: 16, color: c),
        const SizedBox(height: 32),
        Text(
          text,
          style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
