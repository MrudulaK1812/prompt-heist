import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/router.dart';
import 'core/api/token_store.dart';
import 'core/storage/player_session.dart';
import 'features/player/kicked_state.dart';

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

    return MaterialApp.router(
      title: 'Prompt Heist',
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'AppSans',
        fontFamilyFallback: const ['AppEmoji'],
      ),
    );
  }
}
