import 'package:flutter_riverpod/flutter_riverpod.dart';

class JoinSession {
  const JoinSession({
    required this.joinToken,
    required this.expiresAt,
    required this.slotNumber,
    required this.capacity,
    required this.shape,
  });

  final String joinToken;
  final DateTime expiresAt;
  final int slotNumber;
  final int capacity;
  final String shape;

  factory JoinSession.fromJson(Map<String, dynamic> j) {
    final slot = Map<String, dynamic>.from(j['slot'] as Map);
    return JoinSession(
      joinToken: j['joinToken'] as String,
      expiresAt: DateTime.parse(j['expiresAt'] as String),
      slotNumber: slot['slotNumber'] as int,
      capacity: slot['capacity'] as int,
      shape: slot['shape'] as String,
    );
  }
}

class JoinNotifier extends Notifier<JoinSession?> {
  @override
  JoinSession? build() => null;
  void set(JoinSession s) => state = s;
  void clear() => state = null;
}

/// Lives in memory only. FE-06 reads the joinToken from here.
final joinSessionProvider = NotifierProvider<JoinNotifier, JoinSession?>(
  JoinNotifier.new,
);
