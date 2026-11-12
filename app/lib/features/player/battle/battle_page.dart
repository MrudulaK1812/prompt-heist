import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/flavor.dart';
import '../../../core/api/token_store.dart';
import '../../../core/socket/game_socket.dart';
import '../../../core/socket/socket_providers.dart';
import '../../../core/storage/player_session.dart';
import '../../../core/time/countdown.dart';
import '../../../shared/countdown_pill.dart';
import '../../../shared/score_colors.dart';
import 'game_state.dart';
import 'prompt_tile.dart';

const _blue = Color(0xFF4285F4);
const _red = Color(0xFFEA4335);

class BattlePage extends ConsumerStatefulWidget {
  const BattlePage({super.key});

  @override
  ConsumerState<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends ConsumerState<BattlePage> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _left = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    if (_text.text.trim().isEmpty) return;
    ref.read(gameProvider.notifier).submit(_text.text);
    _text.clear();
    _focus.requestFocus(); // keep the keyboard open
    setState(() {});
  }

  void _edit(String text) {
    _text.text = text;
    _text.selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Another device took over this player.
    ref.listen<bool>(gameProvider.select((g) => g.superseded), (prev, now) {
      if (now && !_left) {
        _left = true;
        forgetPlayerToken();
        ref.read(tokenProvider.notifier).set(null);
        context.go('/player/kicked');
      }
    });

    final game = ref.watch(gameProvider);
    final clock = ref.watch(countdownProvider);
    final socket = ref.watch(playerSocketProvider);
    final socketStatus =
        ref.watch(socketStatusProvider).value ?? socket.currentStatus;
    final reconnecting = socketStatus == SocketStatus.reconnecting;

    if (!game.ready || game.round == null || game.treasure == null) {
      return const Scaffold(
        body: Center(child: Text('Waiting for the round to start…')),
      );
    }

    final total = game.round!.durationSeconds * 1000;
    final progress = clock.active
        ? (clock.remaining.inMilliseconds / total).clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const CountdownPill(),
                  const Spacer(),
                  _BestChip(
                    game.bestScore,
                    // Mock only: long-press to test the reconnecting state.
                    onLongPress: currentFlavor == Flavor.mock
                        ? () => socket.simulateOffline(
                            const Duration(seconds: 10),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.black12,
              color: clock.expired ? _red : _blue,
            ),
            if (reconnecting) const _ReconnectingBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TreasureCard(game.treasure!),
                  const SizedBox(height: 16),
                  if (game.prompts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Write a prompt below to convince the Guard.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  for (final p in game.prompts.reversed)
                    PromptTile(
                      p,
                      key: ValueKey(p.key),
                      onRetry: () => ref.read(gameProvider.notifier).retry(p),
                      onEdit: () => _edit(p.text),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('promptField'),
                      controller: _text,
                      focusNode: _focus,
                      enabled: game.canSubmit,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 200,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Write your prompt…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton.filled(
                      key: const Key('sendButton'),
                      style: IconButton.styleFrom(backgroundColor: _blue),
                      onPressed: game.canSubmit && _text.text.trim().isNotEmpty
                          ? _send
                          : null,
                      icon: const Icon(Icons.send_rounded),
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

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFFFFF4D6),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: const Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Reconnecting… your game is still running.',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _BestChip extends StatelessWidget {
  const _BestChip(this.best, {this.onLongPress});
  final int? best;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = best == null ? Colors.black45 : scoreColor(best!);
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Best: ${best ?? '—'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TreasureCard extends StatelessWidget {
  const _TreasureCard(this.t);
  final Treasure t;

  void _story(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.backstory,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: _TreasureImage(t.imageUrl)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'LOCK OBJECTIVE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(t.lockObjective),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: TextButton.icon(
              onPressed: () => _story(context),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('Read the story'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A missing or slow image never blocks the timer or the input.
class _TreasureImage extends StatelessWidget {
  const _TreasureImage(this.url);
  final String url;

  Widget _placeholder() => Container(
    color: const Color(0xFFEAF1FE),
    alignment: Alignment.center,
    child: const Icon(Icons.diamond_outlined, size: 56, color: _blue),
  );

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : _placeholder(),
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }
}
