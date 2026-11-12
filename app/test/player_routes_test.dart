import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/features/player/player_routes.dart';

void main() {
  test('restored state picks the right screen', () {
    expect(routeForPlayerState('LOBBY'), '/player/lobby');
    expect(routeForPlayerState('PLAYING'), '/player/battle');
    expect(routeForPlayerState('LOCKED_100'), '/player/battle');
    expect(routeForPlayerState('RESULT_PENDING'), '/player/timeup');
    expect(routeForPlayerState('COMPLETE'), '/player/result');
  });
}
