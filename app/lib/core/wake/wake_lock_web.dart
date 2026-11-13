import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool _started = false;

Future<void> _request() async {
  try {
    await web.window.navigator.wakeLock.request('screen').toDart;
  } catch (_) {
    // Browser refused or doesn't support it: ignore, the show still works.
  }
}

/// Asks the browser not to dim or sleep the screen.
/// The lock is released when the tab is hidden, so ask again when it returns.
Future<void> keepScreenAwake() async {
  if (_started) return;
  _started = true;
  await _request();
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (web.document.visibilityState == 'visible') _request();
    }).toJS,
  );
}
