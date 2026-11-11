import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          TextButton(
            onPressed: () => context.go('/player'),
            child: const Text('Back'),
          ),
        ],
      ),
    ),
  );
}
