import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/features/player/join/booth_code_page.dart';

void main() {
  testWidgets('claimed code shows a message and stays on the screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: BoothCodePage())),
    );

    await tester.enterText(find.byKey(const Key('code0')), '9');
    await tester.enterText(find.byKey(const Key('code1')), '9');
    await tester.pump();
    await tester.tap(find.text('Join'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('boothError')), findsOneWidget);
    expect(find.textContaining('already taken'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget); // still on the booth screen
  });
}
