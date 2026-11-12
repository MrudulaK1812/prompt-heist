import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/player_api.dart';
import 'join_state.dart';
import '../../../core/api/token_store.dart';
import '../../../core/storage/player_session.dart';

const _blue = Color(0xFF4285F4);
const _red = Color(0xFFEA4335);

String boothErrorText(Object e) {
  if (e is ApiException) {
    switch (e.code) {
      case 'CODE_INVALID':
        return 'That code is not right. Check the number at the booth and try again.';
      case 'CODE_ALREADY_CLAIMED':
        return 'That code is already taken. Ask the booth team for yours.';
      case 'NO_ACTIVE_SESSION':
        return 'No game is open right now. Please wait for the booth team.';
      case 'NETWORK_ERROR':
        return 'Cannot reach the server. Check your connection and try again.';
      default:
        return e.message;
    }
  }
  return 'Something went wrong. Please try again.';
}

class BoothCodePage extends ConsumerStatefulWidget {
  const BoothCodePage({super.key});

  @override
  ConsumerState<BoothCodePage> createState() => _BoothCodePageState();
}

class _BoothCodePageState extends ConsumerState<BoothCodePage> {
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _f1 = FocusNode();
  final _f2 = FocusNode();
  bool _busy = false;
  String? _error;

  String get _code => _c1.text + _c2.text;
  bool get _ready => _code.length == 2 && !_busy;

  @override
  void initState() {
    super.initState();

    // A saved token means this tab already joined. Go straight back.
    final saved = loadPlayerToken();

    if (saved != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(tokenProvider.notifier).set(saved);
        context.go('/player/lobby');
      });
    }
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _f1.dispose();
    _f2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_ready) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final r = await ref.read(playerApiProvider).joinCode(_code);
      ref.read(joinSessionProvider.notifier).set(JoinSession.fromJson(r));

      if (!mounted) return;
      context.go('/player/join');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = boothErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _box(
    Key key,
    TextEditingController c,
    FocusNode f, {
    ValueChanged<String>? onSubmitted,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 72,
      child: TextField(
        key: key,
        controller: c,
        focusNode: f,
        autofocus: key == const Key('code0'),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: const TextStyle(
          fontFamily: 'AppMono',
          fontSize: 36,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: _error != null ? _red : Colors.black26,
            ),
          ),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
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
                children: [
                  const Text(
                    'Enter your booth code',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Two digits, from the booth screen.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _box(
                        const Key('code0'),
                        _c1,
                        _f1,
                        onChanged: (v) {
                          setState(() => _error = null);
                          if (v.isNotEmpty) _f2.requestFocus();
                        },
                      ),
                      const SizedBox(width: 14),
                      _box(
                        const Key('code1'),
                        _c2,
                        _f2,
                        onSubmitted: (_) => _submit(),
                        onChanged: (v) {
                          setState(() => _error = null);
                          if (v.isEmpty) _f1.requestFocus();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        key: const Key('boothError'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _red),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _blue),
                      onPressed: _ready ? _submit : null,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Join', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/player/rejoin'),
                    child: const Text('Rejoin a game'),
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
