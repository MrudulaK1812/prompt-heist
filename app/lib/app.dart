import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Prompt Heist',
      routerConfig: ref.watch(routerProvider),
      theme: ThemeData(useMaterial3: true, fontFamily: 'AppSans'),
    );
  }
}
