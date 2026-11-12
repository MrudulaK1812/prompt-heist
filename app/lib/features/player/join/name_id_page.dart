import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/player_api.dart';
import '../../../core/api/token_store.dart';
import '../../../core/storage/player_session.dart';
import 'join_state.dart';

const _blue = Color(0xFF4285F4);
const _red = Color(0xFFEA4335);

class NameIdPage extends ConsumerStatefulWidget {
  const NameIdPage({super.key});

  @override
  ConsumerState<NameIdPage> createState() => _NameIdPageState();
}

class _NameIdPageState extends ConsumerState<NameIdPage> {
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _idFocus = FocusNode();
  bool _busy = false;
  bool _mustRestart = false;
  String? _nameError, _idError, _generalError;

  @override
  void initState() {
    super.initState();

    // The join token lives in memory only. After a refresh it is gone.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(joinSessionProvider) == null) {
        context.go('/player');
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final id = _id.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'Please enter your name.' : null;
      _idError = id.isEmpty ? 'Please enter your entrance ID.' : null;
      _generalError = null;
    });

    if (name.isEmpty || id.isEmpty || _busy) return;

    final join = ref.read(joinSessionProvider);

    if (join == null) {
      context.go('/player');
      return;
    }

    setState(() => _busy = true);

    try {
      final r = await ref
          .read(playerApiProvider)
          .join(joinToken: join.joinToken, fullName: name, entranceId: id);

      final token = r['playerToken'] as String;
      savePlayerToken(token);
      ref.read(tokenProvider.notifier).set(token);
      ref.read(joinSessionProvider.notifier).clear();

      if (!mounted) return;
      context.go('/player/lobby');
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object e) {
    setState(() {
      if (e is! ApiException) {
        _generalError = 'Something went wrong. Please try again.';
        return;
      }

      switch (e.code) {
        case 'NAME_REQUIRED':
          _nameError = 'Please enter your name.';
        case 'ENTRANCE_ID_REQUIRED':
          _idError = 'Please enter your entrance ID.';
        case 'ENTRANCE_ID_IN_SESSION':
          _idError =
              'This entrance ID is already in this game. '
              'If that is you, go back and use "Rejoin a game".';
        case 'ENTRANCE_ID_USED':
          _idError = 'This entrance ID has already played.';
        case 'CODE_ALREADY_CLAIMED':
          _generalError =
              'That spot was just taken. Enter your booth code again.';
          _mustRestart = true;
        case 'JOIN_TOKEN_EXPIRED':
          _generalError = 'Your code expired. Enter your booth code again.';
          _mustRestart = true;
        case 'NETWORK_ERROR':
          _generalError =
              'Cannot reach the server. Check your connection and try again.';
        default:
          _generalError = e.message;
      }
    });
  }

  void _restart() {
    ref.read(joinSessionProvider.notifier).clear();
    context.go('/player');
  }

  InputDecoration _dec(String label, String? error) => InputDecoration(
    labelText: label,
    errorText: error,
    errorMaxLines: 3,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

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
                  const Text(
                    'Your details',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('nameField'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(80)],
                    decoration: _dec('Full name', _nameError),
                    onChanged: (_) => setState(() => _nameError = null),
                    onSubmitted: (_) => _idFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('idField'),
                    controller: _id,
                    focusNode: _idFocus,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [LengthLimitingTextInputFormatter(128)],
                    decoration: _dec('Entrance ID', _idError),
                    onChanged: (_) => setState(() => _idError = null),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  if (_generalError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _generalError!,
                        key: const Key('joinError'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _red),
                      ),
                    ),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _blue),
                      onPressed: _busy
                          ? null
                          : (_mustRestart ? _restart : _submit),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _mustRestart ? 'Enter code again' : 'Join',
                              style: const TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _restart, child: const Text('Back')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
