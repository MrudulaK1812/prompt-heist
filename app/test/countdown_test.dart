import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/core/time/countdown_math.dart';

void main() {
  test('phone clock 2 minutes wrong still shows the right time', () {
    final phone = DateTime.utc(2026, 11, 11, 10, 0, 0);
    final server = phone.add(const Duration(minutes: 2)); // server clock ahead
    final left = remainingFor(
      roundEndAt: server.add(const Duration(seconds: 90)),
      serverNow: server,
      receivedAt: phone,
      now: phone.add(const Duration(seconds: 10)), // 10s later on the phone
    );
    expect(left, const Duration(seconds: 80));
  });

  test('never goes below zero', () {
    final t = DateTime.utc(2026, 11, 11, 10, 0, 0);
    final left = remainingFor(
      roundEndAt: t,
      serverNow: t,
      receivedAt: t,
      now: t.add(const Duration(seconds: 5)),
    );
    expect(left, Duration.zero);
  });

  test('formats as mm:ss and rounds up', () {
    expect(formatCountdown(const Duration(seconds: 80)), '01:20');
    expect(formatCountdown(const Duration(milliseconds: 79200)), '01:20');
    expect(formatCountdown(Duration.zero), '00:00');
  });
}
