import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/countdown_pill.dart';
import '../../core/socket/socket_providers.dart';

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socket = ref.watch(playerSocketProvider);
    final status =
        ref.watch(socketStatusProvider).value ?? socket.currentStatus;
    final me = ref.watch(meProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Socket: ${status.name}'),
            Text(
              me.when(
                data: (d) => 'Hydrated at ${d['serverNow']}',
                loading: () => 'Hydrating...',
                error: (e, _) => 'Error: ${errorText(e)}',
              ),
            ),
            const SizedBox(height: 12),
            const CountdownPill(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  socket.simulateOffline(const Duration(seconds: 10)),
              child: const Text('Cut network 10s'),
            ),
          ],
        ),
      ),
    );
  }
}
