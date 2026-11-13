import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/token_store.dart';
import '../../../core/storage/player_session.dart';

const _yellow = Color(0xFFFBBC05);

class CancelledPage extends ConsumerStatefulWidget {
  const CancelledPage({super.key});

  @override
  ConsumerState<CancelledPage> createState() => _CancelledPageState();
}

class _CancelledPageState extends ConsumerState<CancelledPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Clear this phone now, so a refresh also lands on the booth code screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      forgetPlayerToken();
      ref.read(tokenProvider.notifier).set(null);
    });
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) context.go('/player');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: _yellow.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cancel_outlined,
                      size: 42,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'This round was cancelled',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Please go back to the booth. The team will help you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => context.go('/player'),
                    child: const Text('Back to start'),
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
