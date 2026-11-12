import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/socket/game_socket.dart';
import '../../../core/socket/socket_providers.dart';

class PublicPlayer {
  const PublicPlayer({
    required this.slotNumber,
    required this.label,
    required this.shape,
    this.connection = 'CONNECTED',
  });
  final int slotNumber;
  final String label;
  final String shape;
  final String connection;

  factory PublicPlayer.fromJson(Map<String, dynamic> j) => PublicPlayer(
    slotNumber: (j['slotNumber'] as num).toInt(),
    label: '${j['label']}',
    shape: '${j['shape']}',
    connection: '${j['connection'] ?? 'CONNECTED'}',
  );

  PublicPlayer withConnection(String c) => PublicPlayer(
    slotNumber: slotNumber,
    label: label,
    shape: shape,
    connection: c,
  );
}

class LobbyState {
  const LobbyState({
    this.ready = false,
    this.joinedCount = 0,
    this.capacity = 5,
    this.players = const [],
    this.mySlot,
    this.myLabel,
    this.myShape,
    this.roundStarted = false,
  });

  final bool ready; // hydrate data has arrived
  final int joinedCount;
  final int capacity;
  final List<PublicPlayer> players; // empty until names are revealed
  final int? mySlot;
  final String? myLabel;
  final String? myShape;
  final bool roundStarted;

  bool get revealed => players.isNotEmpty;

  LobbyState copyWith({
    int? joinedCount,
    int? capacity,
    List<PublicPlayer>? players,
    bool? roundStarted,
  }) => LobbyState(
    ready: ready,
    joinedCount: joinedCount ?? this.joinedCount,
    capacity: capacity ?? this.capacity,
    players: players ?? this.players,
    mySlot: mySlot,
    myLabel: myLabel,
    myShape: myShape,
    roundStarted: roundStarted ?? this.roundStarted,
  );

  factory LobbyState.fromMe(Map<String, dynamic> me) {
    final player = Map<String, dynamic>.from(me['player'] as Map);
    final session = Map<String, dynamic>.from(me['session'] as Map);
    final list = (me['players'] as List?) ?? const [];
    return LobbyState(
      ready: true,
      joinedCount: (session['joinedCount'] as num).toInt(),
      capacity: (session['capacity'] as num).toInt(),
      players: [
        for (final p in list)
          PublicPlayer.fromJson(Map<String, dynamic>.from(p as Map)),
      ],
      mySlot: (player['slotNumber'] as num).toInt(),
      myLabel: '${player['label']}',
      myShape: '${player['shape']}',
      roundStarted: me['round'] != null && session['phase'] == 'PLAYING',
    );
  }
}

class LobbyNotifier extends Notifier<LobbyState> {
  @override
  LobbyState build() {
    // Rebuilds from the server every time the hydrate call is refreshed.
    final me = ref.watch(meProvider).value;
    final sub = ref.watch(playerSocketProvider).messages.listen(_onMessage);
    ref.onDispose(sub.cancel);
    return me == null ? const LobbyState() : LobbyState.fromMe(me);
  }

  void _onMessage(SocketMessage m) {
    final d = m.data;
    if (d is! Map) return;
    switch (m.event) {
      case 'player:joined':
        // Counts only. Names stay hidden until players:revealed.
        state = state.copyWith(
          joinedCount: (d['joinedCount'] as num?)?.toInt(),
          capacity: (d['capacity'] as num?)?.toInt(),
        );
      case 'players:revealed':
        final list = (d['players'] as List?) ?? const [];
        state = state.copyWith(
          players: [
            for (final p in list)
              PublicPlayer.fromJson(Map<String, dynamic>.from(p as Map)),
          ],
        );
      case 'player:connection':
        final slot = (d['slotNumber'] as num?)?.toInt();
        state = state.copyWith(
          players: [
            for (final p in state.players)
              p.slotNumber == slot ? p.withConnection('${d['connection']}') : p,
          ],
        );
      case 'round:started':
        state = state.copyWith(roundStarted: true);
    }
  }
}

final lobbyProvider = NotifierProvider<LobbyNotifier, LobbyState>(
  LobbyNotifier.new,
);
