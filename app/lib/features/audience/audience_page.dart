import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/flavor.dart';
import 'audience_state.dart';
import 'audience_battle.dart';

const _blue = Color(0xFF4285F4);
const _red = Color(0xFFEA4335);
const _yellow = Color(0xFFFBBC05);
const _green = Color(0xFF34A853);
const _grey = Color(0xFF5F6368);
const _slotColors = [_blue, _red, _yellow, _green, _grey];

class _Slot {
  final int number; // 1..5
  final bool joined;
  final String? name; // only filled after players:revealed
  const _Slot(this.number, this.joined, this.name);
}

class AudiencePage extends ConsumerWidget {
  const AudiencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(audienceProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
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
        return _JoiningScreen(slots: _slots(a), revealed: _revealed(a));
      case 'GET_READY':
      case 'STARTING':
      case 'COUNTDOWN':
        return _GetReadyScreen(slots: _slots(a));
      case 'PLAYING':
        return AudienceBattle(data: a.data); // FE-21 replaces
      case 'RESULT_PENDING':
      case 'RESULTS':
        return _simple('Results', _green); // later
      default:
        return const _IdleScreen();
    }
  }

  // ---------- data helpers ----------

  bool _revealed(AudienceState a) {
    if (currentFlavor == Flavor.mock) {
      return Uri.base.queryParameters['revealed'] == '1';
    }
    return a.data['revealed'] == true || a.data['playersRevealed'] == true;
  }

  List<_Slot> _slots(AudienceState a) {
    final revealed = _revealed(a);
    if (currentFlavor == Flavor.mock) {
      // /audience?phase=LOBBY&joined=3&revealed=1
      final joined =
          int.tryParse(Uri.base.queryParameters['joined'] ?? '') ?? 0;
      const names = ['Rohan', 'Priya', 'Meera', 'Isha', 'Kabir'];
      return [
        for (var i = 0; i < 5; i++)
          _Slot(i + 1, i < joined, revealed && i < joined ? names[i] : null),
      ];
    }
    final raw = (a.data['players'] ?? a.data['slots'] ?? const []) as List;
    final byNumber = <int, Map>{};
    for (final p in raw) {
      if (p is Map) {
        final n = (p['slotNumber'] as num?)?.toInt();
        if (n != null) byNumber[n] = p;
      }
    }
    return [
      for (var i = 1; i <= 5; i++)
        _Slot(
          i,
          byNumber.containsKey(i),
          // Never show a name until the server says players are revealed.
          revealed ? (byNumber[i]?['name'] as String?) : null,
        ),
    ];
  }

  Widget _simple(String text, Color c) => Center(
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

// ================= IDLE =================

class _IdleScreen extends StatelessWidget {
  const _IdleScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in [_blue, _red, _yellow, _green])
                Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 56),
          const Text(
            'Prompt Heist',
            style: TextStyle(
              fontSize: 160,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Talk your way past the guard and unlock the treasure.',
            style: TextStyle(fontSize: 48, color: _grey),
          ),
          const SizedBox(height: 72),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Text(
              'Come to the booth to play the next battle',
              style: TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= JOINING =================

class _JoiningScreen extends StatelessWidget {
  final List<_Slot> slots;
  final bool revealed;
  const _JoiningScreen({required this.slots, required this.revealed});

  @override
  Widget build(BuildContext context) {
    final joined = slots.where((s) => s.joined).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 90, vertical: 80),
      child: Column(
        children: [
          const Text(
            'Players are joining',
            style: TextStyle(fontSize: 104, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(
            '$joined of 5 ready',
            style: const TextStyle(fontSize: 48, color: _grey),
          ),
          const Spacer(),
          Row(
            children: [
              for (final s in slots) ...[
                Expanded(child: _SlotCard(slot: s)),
                if (s.number != 5) const SizedBox(width: 28),
              ],
            ],
          ),
          const Spacer(),
          Text(
            revealed
                ? 'Everyone is in. Here we go!'
                : 'Names appear when the battle is ready.',
            style: const TextStyle(fontSize: 40, color: _grey),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final _Slot slot;
  const _SlotCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    final color = _slotColors[slot.number - 1];
    final on = slot.joined;
    // Before reveal we only ever show "Player N" and never a real name.
    final label = slot.name == null
        ? 'Player ${slot.number}'
        : '${slot.name} (Player ${slot.number})';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: on ? color.withValues(alpha: 0.12) : const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: on ? color : const Color(0xFFDADCE0),
          width: 4,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? color : const Color(0xFFDADCE0),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${slot.number}',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: on && color != _yellow ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            on ? 'Ready' : 'Waiting…',
            style: TextStyle(fontSize: 30, color: on ? _green : _grey),
          ),
        ],
      ),
    );
  }
}

// ================= GET READY =================

class _GetReadyScreen extends StatelessWidget {
  final List<_Slot> slots;
  const _GetReadyScreen({required this.slots});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Get ready!',
            style: TextStyle(fontSize: 200, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          const Text(
            'The battle starts any second.',
            style: TextStyle(fontSize: 56, color: _grey),
          ),
          const SizedBox(height: 72),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in slots.where((s) => s.joined))
                Container(
                  width: 110,
                  height: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _slotColors[s.number - 1],
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${s.number}',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: s.number == 3 ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
