import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

enum SocketStatus { connecting, connected, reconnecting }

class SocketMessage {
  SocketMessage(this.event, this.data);
  final String event;
  final dynamic data;
}

/// One connection to one namespace: /player, /display or /controller.
/// Every time the socket (re)connects, [onHydrate] is called so the app
/// reloads its state from REST. Sockets only send server -> client.
class GameSocket {
  GameSocket({
    required this.baseUrl,
    required this.namespace, // e.g. '/player'
    required this.onHydrate,
    this.token,
  });

  final String baseUrl;
  final String namespace;
  final String? token;
  final Future<void> Function() onHydrate;

  io.Socket? _socket;
  final _messages = StreamController<SocketMessage>.broadcast();
  final _status = StreamController<SocketStatus>.broadcast();
  SocketStatus _current = SocketStatus.connecting;

  Stream<SocketMessage> get messages => _messages.stream;
  Stream<SocketStatus> get status => _status.stream;
  SocketStatus get currentStatus => _current;

  void connect() {
    final opts = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .setReconnectionAttempts(1 << 30) // effectively forever
        .setAuth(token == null ? {} : {'token': token})
        .build();

    final s = io.io('$baseUrl$namespace', opts);
    _socket = s;

    s.onConnect((_) async {
      _set(SocketStatus.connected);
      try {
        await onHydrate(); // after EVERY connect, first or reconnect
      } catch (_) {
        /* the caller shows its own error state */
      }
    });
    s.onDisconnect((_) => _set(SocketStatus.reconnecting));
    s.onConnectError((_) => _set(SocketStatus.reconnecting));
    s.onAny((event, data) => _messages.add(SocketMessage(event, data)));

    s.connect();
  }

  void _set(SocketStatus v) {
    _current = v;
    _status.add(v);
  }

  void dispose() {
    _socket?.dispose();
    _messages.close();
    _status.close();
  }
}
