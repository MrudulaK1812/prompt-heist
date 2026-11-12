import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config/flavor.dart';

enum SocketStatus { connecting, connected, reconnecting }

class SocketMessage {
  SocketMessage(this.event, this.data);
  final String event;
  final dynamic data;
}

/// One connection to one namespace (/player, /display, /controller).
/// After EVERY connect or reconnect, [onHydrate] runs so the app reloads
/// its state over REST. Sockets only receive; all writes go through REST.
class GameSocket {
  GameSocket({required this.namespace, required this.onHydrate, this.token});

  final String namespace;
  final String? token;
  final Future<void> Function() onHydrate;

  // Test a wrong phone clock with: --dart-define=MOCK_CLOCK_SKEW=120
  static const _skew = Duration(
    seconds: int.fromEnvironment('MOCK_CLOCK_SKEW', defaultValue: 0),
  );

  io.Socket? _socket;
  Timer? _mockTimer;
  final _scriptTimers = <Timer>[];
  DateTime? _mockEnd;
  bool _disposed = false;
  SocketStatus _current = SocketStatus.connecting;

  final _messages = StreamController<SocketMessage>.broadcast();
  final _status = StreamController<SocketStatus>.broadcast();

  Stream<SocketMessage> get messages => _messages.stream;
  Stream<SocketStatus> get status => _status.stream;
  SocketStatus get currentStatus => _current;

  void connect() =>
      currentFlavor == Flavor.mock ? _connectMock() : _connectReal();

  void _connectReal() {
    final opts = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .setReconnectionAttempts(1 << 30)
        .setAuth(token == null ? {} : {'token': token})
        .build();

    final s = io.io('$apiBaseUrl$namespace', opts);
    _socket = s;
    s.onConnect((_) => _onConnected());
    s.onDisconnect((_) => _set(SocketStatus.reconnecting));
    s.onConnectError((_) => _set(SocketStatus.reconnecting));
    s.onAny((event, data) => _emit(event, data));
    s.connect();
  }

  void _connectMock() {
    _mockTimer?.cancel();
    Future<void>.delayed(Duration.zero, _onConnected);
    Future<void>.delayed(const Duration(milliseconds: 300), _sendMockSync);
    _mockTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _sendMockSync(),
    );
  }

  void _sendMockSync() {
    final now = DateTime.now().toUtc();
    // One 90 second round. 5 seconds after it ends, start a new one.
    if (_mockEnd == null ||
        now.isAfter(_mockEnd!.add(const Duration(seconds: 5)))) {
      _mockEnd = now.add(const Duration(seconds: 90));
    }
    _emit('timer:sync', {
      'roundId': 'rnd_1',
      'roundEndAt': _mockEnd!.add(_skew).toIso8601String(),
      'serverNow': now.add(_skew).toIso8601String(),
    });
  }

  /// Mock only: plays a lobby filling up, names revealed, then the round starting.
  void mockLobbyScript({required String myLabel}) {
    for (final t in _scriptTimers) {
      t.cancel();
    }
    _scriptTimers.clear();

    void at(int sec, void Function() fn) => _scriptTimers.add(
      Timer(Duration(seconds: sec), () {
        if (!_disposed) fn();
      }),
    );

    for (var n = 2; n <= 5; n++) {
      at(
        (n - 1) * 2,
        () => _emit('player:joined', {'joinedCount': n, 'capacity': 5}),
      );
    }
    at(10, () {
      _emit('players:revealed', {
        'players': [
          {
            'slotNumber': 1,
            'label': myLabel,
            'shape': 'BLUE_CIRCLE',
            'connection': 'CONNECTED',
          },
          {
            'slotNumber': 2,
            'label': 'Priya',
            'shape': 'RED_SQUARE',
            'connection': 'CONNECTED',
          },
          {
            'slotNumber': 3,
            'label': 'Rohan',
            'shape': 'YELLOW_DIAMOND',
            'connection': 'CONNECTED',
          },
          {
            'slotNumber': 4,
            'label': 'Meera',
            'shape': 'GREEN_PILL',
            'connection': 'CONNECTED',
          },
          {
            'slotNumber': 5,
            'label': 'Isha',
            'shape': 'GREEN_CIRCLE',
            'connection': 'CONNECTED',
          },
        ],
      });
    });
    at(14, () {
      final now = DateTime.now().toUtc();
      _emit('round:started', {
        'roundId': 'rnd_1',
        'roundNumber': 1,
        'durationSeconds': 90,
        'startedAt': now.toIso8601String(),
        'roundEndAt': now.add(const Duration(seconds: 90)).toIso8601String(),
        'serverNow': now.toIso8601String(),
        'treasure': {
          'treasureId': 'cnd_1',
          'title': 'The Golden Chai Cup',
          'backstory': 'Mock backstory.',
          'lockObjective': 'Mock objective.',
          'imageUrl': '',
        },
      });
    });
  }

  /// Mock only: pretend the server kicked this device.
  void mockKick() =>
      _emit('player:kicked', {'reason': 'REJOINED_ON_ANOTHER_DEVICE'});

  Future<void> _onConnected() async {
    if (_disposed) return;
    _set(SocketStatus.connected);
    try {
      await onHydrate();
    } catch (_) {
      /* the screen shows its own error state */
    }
  }

  void _emit(String event, dynamic data) {
    if (!_disposed) _messages.add(SocketMessage(event, data));
  }

  void _set(SocketStatus v) {
    if (_disposed) return;
    _current = v;
    _status.add(v);
  }

  /// Test helper for the QE check: drop the connection, come back after [d].
  void simulateOffline(Duration d) {
    _set(SocketStatus.reconnecting);
    _mockTimer?.cancel();
    _socket?.disconnect();
    Future<void>.delayed(d, () {
      if (_disposed) return;
      if (currentFlavor == Flavor.mock) {
        _connectMock();
      } else {
        _socket?.connect();
      }
    });
  }

  void dispose() {
    _disposed = true;
    _mockTimer?.cancel();
    for (final t in _scriptTimers) {
      t.cancel();
    }
    _socket?.dispose();
    _messages.close();
    _status.close();
  }
}
