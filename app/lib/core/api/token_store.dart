import 'package:flutter_riverpod/flutter_riverpod.dart';

class TokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? token) => state = token;
}

/// Current bearer token (join, player or controller token, set by the screen).
final tokenProvider = NotifierProvider<TokenNotifier, String?>(
  TokenNotifier.new,
);
