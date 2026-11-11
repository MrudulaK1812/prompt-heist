/// Time left, using the server's clock instead of the phone's.
Duration remainingFor({
  required DateTime roundEndAt,
  required DateTime serverNow, // server clock when the message was sent
  required DateTime receivedAt, // phone clock when it arrived
  required DateTime now, // phone clock now
}) {
  final offset = serverNow.difference(receivedAt); // server minus phone
  final serverTimeNow = now.add(offset);
  final left = roundEndAt.difference(serverTimeNow);
  return left.isNegative ? Duration.zero : left;
}

/// 80 seconds -> "01:20". Rounds up, so 00:00 only shows when time is truly up.
String formatCountdown(Duration d) {
  final total = (d.inMilliseconds / 1000).ceil();
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
