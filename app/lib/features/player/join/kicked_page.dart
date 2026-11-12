import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _yellow = Color(0xFFFBBC05);

class KickedPage extends StatelessWidget {
  const KickedPage({super.key});

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
                      Icons.devices_other_rounded,
                      size: 40,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'You joined on another device',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This phone has stopped playing. Carry on with the other device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
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
