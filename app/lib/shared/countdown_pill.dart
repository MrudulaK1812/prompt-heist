import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time/countdown.dart';

const _red = Color(0xFFEA4335);

class CountdownPill extends ConsumerWidget {
  const CountdownPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(countdownProvider);
    if (!c.active) return const SizedBox.shrink();
    final color = c.expired ? _red : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color ?? Colors.black26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.label,
            style: TextStyle(
              fontFamily: 'AppMono',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (c.reconnecting) ...[
            const SizedBox(width: 10),
            const Text('Reconnecting…', style: TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
