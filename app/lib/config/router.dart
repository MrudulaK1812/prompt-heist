import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/player/player_page.dart';
import '../features/player/join/booth_code_page.dart';
import '../features/audience/audience_page.dart' deferred as audience;
import '../features/controller/controller_page.dart' deferred as controller;
import '../shared/deferred_page.dart';
import '../shared/placeholder_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/player',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/player'),
      GoRoute(path: '/player', builder: (_, _) => const BoothCodePage()),
      GoRoute(
        path: '/player/join',
        builder: (_, _) => const PlaceholderPage('Name and ID (FE-06)'),
      ),
      GoRoute(
        path: '/player/rejoin',
        builder: (_, _) => const PlaceholderPage('Rejoin (FE-07)'),
      ),
      // Old test screen (socket + countdown). Remove once FE-08 lands.
      GoRoute(path: '/dev', builder: (_, _) => const PlayerPage()),
      GoRoute(
        path: '/audience',
        builder: (_, _) => DeferredPage(
          loader: audience.loadLibrary,
          builder: (_) => audience.AudiencePage(),
        ),
      ),
      GoRoute(
        path: '/controller',
        builder: (_, _) => DeferredPage(
          loader: controller.loadLibrary,
          builder: (_) => controller.ControllerPage(),
        ),
      ),
    ],
  );
});
