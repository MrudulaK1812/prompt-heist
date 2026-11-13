import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/wake/wake_lock.dart';

class AudienceState {
  final bool ready; // first hydrate done
  final bool connected; // last fetch worked
  final String phase;
  final Map<String, dynamic> data;
  const AudienceState({
    this.ready = false,
    this.connected = true,
    this.phase = 'IDLE',
    this.data = const {},
  });
}

class AudienceNotifier extends Notifier<AudienceState> {
  @override
  AudienceState build() {
    keepScreenAwake();
    _load();
    // Re-hydrate every 3s: this is the auto-reconnect safety net.
    final t = Timer.periodic(const Duration(seconds: 3), (_) => _load());
    ref.onDispose(t.cancel);
    return const AudienceState();
  }

  Future<void> _load() async {
    // Mock flavour: test any screen with /audience?phase=PLAYING
    if (currentFlavor == Flavor.mock) {
      final p = Uri.base.queryParameters['phase'] ?? 'IDLE';
      state = AudienceState(ready: true, connected: true, phase: p);
      return;
    }
    try {
      final res = await ref.read(dioProvider).get('/api/display/state');
      if (!ref.mounted) return;
      final data = Map<String, dynamic>.from(res.data as Map);
      final session = data['session'];
      final phase =
          (session is Map ? session['phase'] : data['phase']) ?? 'IDLE';
      state = AudienceState(
        ready: true,
        connected: true,
        phase: '$phase',
        data: data,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AudienceState(
        ready: state.ready,
        connected: false,
        phase: state.phase,
        data: state.data,
      );
    }
  }
}

final audienceProvider = NotifierProvider<AudienceNotifier, AudienceState>(
  AudienceNotifier.new,
);
