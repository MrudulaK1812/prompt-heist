import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/features/player/lobby/lobby_state.dart';

Map<String, dynamic> _me(List players) => {
  'player': {'slotNumber': 1, 'label': 'Aman', 'shape': 'BLUE_CIRCLE'},
  'session': {'phase': 'JOINING', 'capacity': 5, 'joinedCount': 3},
  'players': players,
  'round': null,
};

void main() {
  test('names are hidden until revealed', () {
    final s = LobbyState.fromMe(_me([]));
    expect(s.revealed, isFalse);
    expect(s.joinedCount, 3);
    expect(s.myShape, 'BLUE_CIRCLE');
  });

  test('names show once the player list is present', () {
    final s = LobbyState.fromMe(
      _me([
        {
          'slotNumber': 1,
          'label': 'Aman',
          'shape': 'BLUE_CIRCLE',
          'connection': 'CONNECTED',
        },
        {
          'slotNumber': 2,
          'label': 'Priya',
          'shape': 'RED_SQUARE',
          'connection': 'CONNECTED',
        },
      ]),
    );
    expect(s.revealed, isTrue);
    expect(s.players.length, 2);
  });
}
