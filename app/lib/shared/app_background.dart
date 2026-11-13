import 'package:flutter/material.dart';

/// Soft off-white base with faint Google-colour glows in the corners.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  Widget _glow(Alignment a, Color c) => Positioned.fill(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: a,
          radius: 0.9,
          colors: [c.withValues(alpha: 0.14), c.withValues(alpha: 0)],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFF8F9FA))),
        _glow(Alignment.topLeft, const Color(0xFF4285F4)),
        _glow(Alignment.topRight, const Color(0xFFEA4335)),
        _glow(Alignment.bottomLeft, const Color(0xFFFBBC05)),
        _glow(Alignment.bottomRight, const Color(0xFF34A853)),
        Positioned.fill(child: child),
      ],
    );
  }
}
