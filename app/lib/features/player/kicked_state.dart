import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/token_store.dart';
import '../../core/socket/socket_providers.dart';

/// Turns true when this device receives player:kicked.
class KickedNotifier extends Notifier<bool> {
  @override
  bool build() {
    if (ref.watch(tokenProvider) == null) return false; // not a player yet
    final sub = ref.watch(playerSocketProvider).messages.listen((m) {
      if (m.event == 'player:kicked') state = true;
    });
    ref.onDispose(sub.cancel);
    return false;
  }
}

final kickedProvider = NotifierProvider<KickedNotifier, bool>(
  KickedNotifier.new,
);
