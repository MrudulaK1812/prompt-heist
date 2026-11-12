import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/flavor.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/token_store.dart';
import '../../../core/socket/socket_providers.dart';
import '../../../core/storage/player_session.dart';
import '../../../shared/shape_marker.dart';
import 'lobby_state.dart';

const _blue = Color(0xFF4285F4);

class LobbyPage extends ConsumerStatefulWidget {
  const LobbyPage({super.key});

  @override
  ConsumerState<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends ConsumerState<LobbyPage> {
  bool _left = false; // we are already navigating away
  bool _scripted = false; // mock demo started

  void _leave(String path, {bool forget = true}) {
    if (_left) return;
    _left = true;
    if (forget) {
      forgetPlayerToken();
      ref.read(tokenProvider.notifier).set(null);
    }
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    // Dead sessions: SESSION_CLOSED clears the phone, TOKEN_SUPERSEDED = kicked.
    ref.listen(meProvider, (prev, next) {
      final e = next.error;
      if (e is ApiException) {
        if (e.code == 'SESSION_CLOSED') _leave('/player');
        if (e.code == 'TOKEN_SUPERSEDED') _leave('/player/kicked');
      }
    });

    final lobby = ref.watch(lobbyProvider);

    // round:started moves to the battle with no button.
    if (lobby.roundStarted && !_left) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _leave('/player/battle', forget: false);
      });
    }

    // Mock only: play a lobby filling up, then the round starting.
    if (lobby.ready && !_scripted && currentFlavor == Flavor.mock) {
      _scripted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(playerSocketProvider)
              .mockLobbyScript(myLabel: lobby.myLabel ?? 'You');
        }
      });
    }

    if (!lobby.ready) {
      final failed = ref.watch(meProvider).hasError;
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!failed) const CircularProgressIndicator(),
              if (failed) ...[
                const Text('Cannot reach the server.'),
                TextButton(
                  onPressed: () => ref.invalidate(meProvider),
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final info = shapeInfo[lobby.myShape] ?? shapeInfo['BLUE_CIRCLE']!;
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
                  const Text(
                    'Waiting for players',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShapeMarker(lobby.myShape ?? 'BLUE_CIRCLE', size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Your shape: ${info.name}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '${lobby.joinedCount}/${lobby.capacity} joined',
                    key: const Key('joinedCount'),
                    style: const TextStyle(
                      fontFamily: 'AppMono',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Segments(joined: lobby.joinedCount, total: lobby.capacity),
                  const SizedBox(height: 24),
                  if (lobby.revealed)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in lobby.players)
                          _PlayerPill(p, isMe: p.slotNumber == lobby.mySlot),
                      ],
                    )
                  else
                    const Text(
                      'Names appear when everyone has joined.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'The game starts by itself. Keep this screen open.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
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

class _Segments extends StatelessWidget {
  const _Segments({required this.joined, required this.total});
  final int joined;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < total; i++)
        Expanded(
          child: Container(
            height: 8,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: i < joined ? _blue : Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
    ],
  );
}

class _PlayerPill extends StatelessWidget {
  const _PlayerPill(this.p, {required this.isMe});
  final PublicPlayer p;
  final bool isMe;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: p.connection == 'DISCONNECTED' ? 0.45 : 1,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isMe ? _blue : Colors.black26,
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShapeMarker(p.shape, size: 14),
          const SizedBox(width: 8),
          Text(isMe ? '${p.label} (you)' : p.label),
        ],
      ),
    ),
  );
}
