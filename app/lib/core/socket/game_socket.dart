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

  io.Socket? _socket;
  Timer? _mockTimer;
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
    _mockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _emit('timer:sync', {
        'roundId': 'rnd_1',
        'roundEndAt': DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 90))
            .toIso8601String(),
        'serverNow': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

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
    _socket?.dispose();
    _messages.close();
    _status.close();
  }
}
