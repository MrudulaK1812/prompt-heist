import 'package:flutter/material.dart';

class DeferredPage extends StatefulWidget {
  const DeferredPage({super.key, required this.loader, required this.builder});
  final Future<void> Function() loader;
  final WidgetBuilder builder;

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late final Future<void> _future = widget.loader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Scaffold(body: Center(child: Text('Failed to load')));
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return widget.builder(context);
      },
    );
  }
}
