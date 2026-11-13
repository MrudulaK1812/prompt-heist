import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/router.dart';
import 'core/api/token_store.dart';
import 'core/storage/player_session.dart';
import 'features/player/battle/game_state.dart';
import 'features/player/kicked_state.dart';
import 'shared/app_background.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // player:kicked on any player screen: forget this device and stop.
    ref.listen<bool>(kickedProvider, (prev, kicked) {
      if (!kicked) return;
      forgetPlayerToken();
      ref.read(tokenProvider.notifier).set(null);
      router.go('/player/kicked');
    });

    // The session phase decides the screen. This also keeps game state alive
    // from the lobby onward, so it catches every event.
    ref.listen<String>(gameProvider.select((g) => g.phase), (prev, phase) {
      switch (phase) {
        case 'RESULT_PENDING':
          router.go('/player/timeup');
        case 'RESULTS':
          router.go('/player/result');
        case 'DISCARDED':
          router.go('/player/cancelled');
        case 'CLOSED':
          // Session over: clear this phone, back to the booth code screen.
          forgetPlayerToken();
          ref.read(tokenProvider.notifier).set(null);
          router.go('/player');
      }
    });

    return MaterialApp.router(
      title: 'Prompt Heist',
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'AppSans',
        fontFamilyFallback: const ['AppEmoji'],
        // Pages show the shared background behind them.
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (context, child) =>
          AppBackground(child: child ?? const SizedBox()),
    );
  }
}
