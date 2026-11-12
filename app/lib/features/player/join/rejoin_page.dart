import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/player_api.dart';
import '../../../core/api/token_store.dart';
import '../../../core/storage/player_session.dart';
import '../player_routes.dart';
import 'join_state.dart';

const _blue = Color(0xFF4285F4);
const _red = Color(0xFFEA4335);

String rejoinErrorText(Object e) {
  if (e is ApiException) {
    switch (e.code) {
      case 'NO_ACTIVE_GAME':
        return 'We could not find an active game for that entrance ID. '
            'Check it and try again.';
      case 'TOO_MANY_ATTEMPTS':
        return 'Too many tries. Wait a minute, then try again.';
      case 'NETWORK_ERROR':
        return 'Cannot reach the server. Check your connection and try again.';
      default:
        return e.message;
    }
  }
  return 'Something went wrong. Please try again.';
}

class RejoinPage extends ConsumerStatefulWidget {
  const RejoinPage({super.key});

  @override
  ConsumerState<RejoinPage> createState() => _RejoinPageState();
}

class _RejoinPageState extends ConsumerState<RejoinPage> {
  final _id = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _id.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Please enter your entrance ID.');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(playerApiProvider).rejoin(id);
      final token = r['playerToken'] as String;
      final player = Map<String, dynamic>.from(r['player'] as Map);
      savePlayerToken(token);
      ref.read(joinSessionProvider.notifier).clear();
      ref.read(tokenProvider.notifier).set(token);
      if (!mounted) return;
      context.go(routeForPlayerState('${player['state']}'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = rejoinErrorText(e)); // stay here, allow retries
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.login_rounded,
                        size: 34,
                        color: _blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Rejoin your game',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the entrance ID you joined with.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('rejoinIdField'),
                    controller: _id,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [LengthLimitingTextInputFormatter(128)],
                    decoration: InputDecoration(
                      labelText: 'Entrance ID',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        key: const Key('rejoinError'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _red),
                      ),
                    ),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _blue),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Rejoin',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/player'),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
