import 'dart:async';

/// Mock only: one fake round that the mock REST and mock socket both use.
/// Words in a prompt: "block" = blocked, "fail" = failed, "unlock" = 100,
/// "silent" = finishes but sends NO socket event (tests the 10 second check).
class MockWorld {
  static DateTime? roundEnd; // null = no round running
  static const roundSeconds = 90;
  static int? best;
  static int _seq = 0;
  static final prompts = <Map<String, dynamic>>[];
  static final _byKey = <String, Map<String, dynamic>>{};
  static final events = StreamController<(String, Object?)>.broadcast();

  static const treasure = {
    'treasureId': 'cnd_1',
    'title': 'The Golden Chai Cup',
    'backstory':
        'A sleepy Guard watches over a cup of chai that never goes cold. '
        'Charm him with the right words and the cup is yours.',
    'lockObjective': 'Make the Guard hand over the chai cup.',
    'imageUrl': '',
  };

  static void startRound() {
    roundEnd = DateTime.now().toUtc().add(
      const Duration(seconds: roundSeconds),
    );
    prompts.clear();
    _byKey.clear();
    best = null;
    _seq = 0;
  }

  /// Same key twice returns the stored prompt (isNew = false).
  static (bool, Map<String, dynamic>) submit(String text, String key) {
    final known = _byKey[key];
    if (known != null) return (false, known);
    _seq++;
    final id = 'prm_$_seq';
    final now = DateTime.now().toUtc().toIso8601String();
    final record = {
      'promptId': id,
      'status': 'RECEIVED',
      'sequence': _seq,
      'receivedAt': now,
    };
    _byKey[key] = record;
    prompts.add({
      'promptId': id,
      'text': text,
      'status': 'RECEIVED',
      'score': null,
      'feedback': null,
      'message': null,
      'sequence': _seq,
      'receivedAt': now,
    });
    Future<void>.delayed(const Duration(seconds: 2), () => _finish(id, text));
    return (true, record);
  }

  static void _finish(String id, String text) {
    final p = prompts.firstWhere((e) => e['promptId'] == id);
    final lower = text.toLowerCase();
    final silent = lower.contains('silent');
    void emit(String event, Map<String, dynamic> data) {
      if (!silent) events.add((event, data));
    }

    if (lower.contains('block')) {
      const msg =
          'That prompt cannot be displayed. Try a different game-focused prompt.';
      p['status'] = 'BLOCKED';
      p['message'] = msg;
      emit('prompt:blocked', {'promptId': id, 'message': msg});
      return;
    }
    if (lower.contains('fail')) {
      const msg = 'We could not score that one. Please try again.';
      p['status'] = 'FAILED';
      p['message'] = msg;
      emit('prompt:failed', {'promptId': id, 'message': msg, 'canRetry': true});
      return;
    }
    final score = lower.contains('unlock') ? 100 : (text.length * 7) % 100;
    final feedback = score >= 80
        ? 'The Guard salutes and looks impressed.'
        : score >= 40
        ? 'The Guard raises an eyebrow.'
        : 'The Guard yawns...';
    p['status'] = 'SCORED';
    p['score'] = score;
    p['feedback'] = feedback;
    if (best == null || score > best!) best = score;
    emit('prompt:scored', {
      'promptId': id,
      'score': score,
      'feedback': feedback,
      'bestScore': best,
    });
  }
}
