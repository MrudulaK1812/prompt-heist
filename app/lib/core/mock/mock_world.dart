import 'dart:async';

/// Mock only: one fake game that the mock REST and mock socket both use.
/// Prompt words: "unlock" = 100 and locks you, "finish" = end the round now,
/// "discard" = round cancelled, "block", "fail", "silent" (no socket event).
class MockWorld {
  static String phase =
      'JOINING'; // JOINING PLAYING RESULT_PENDING RESULTS DISCARDED CLOSED
  static DateTime? roundEnd;
  static const roundSeconds = 90;
  static String myLabel = 'Aman';
  static bool locked = false;
  static int? best;
  static int _seq = 0;
  static final prompts = <Map<String, dynamic>>[];
  static final _byKey = <String, Map<String, dynamic>>{};
  static final _timers = <Timer>[];
  static Map<String, dynamic>? _result;
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

  static void reset() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    phase = 'JOINING';
    roundEnd = null;
    locked = false;
    best = null;
    _seq = 0;
    _result = null;
    prompts.clear();
    _byKey.clear();
  }

  static void startRound() {
    reset();
    phase = 'PLAYING';
    roundEnd = DateTime.now().toUtc().add(
      const Duration(seconds: roundSeconds),
    );
    _timers.add(Timer(const Duration(seconds: roundSeconds), endRound));
  }

  /// Time is up (also used by the "finish" prompt word).
  static void endRound() {
    if (phase != 'PLAYING') return;
    phase = 'RESULT_PENDING';
    roundEnd = DateTime.now().toUtc();
    events.add((
      'round:ended',
      {'roundId': 'rnd_1', 'endedAt': roundEnd!.toIso8601String()},
    ));
    _timers.add(Timer(const Duration(seconds: 4), _confirm));
  }

  static void _confirm() {
    if (phase != 'RESULT_PENDING') return;
    final others = [
      ('Rohan', 3, 'YELLOW_DIAMOND', 73),
      ('Priya', 2, 'RED_SQUARE', 58),
      ('Meera', 4, 'GREEN_PILL', 41),
      ('Isha', 5, 'GREEN_CIRCLE', 20),
    ];
    final rows = <Map<String, dynamic>>[
      {
        'slotNumber': 1,
        'label': myLabel,
        'shape': 'BLUE_CIRCLE',
        'bestScore': best,
      },
      for (final o in others)
        {'slotNumber': o.$2, 'label': o.$1, 'shape': o.$3, 'bestScore': o.$4},
    ];
    // A player with no score ranks below everyone with a score.
    rows.sort(
      (a, b) => ((b['bestScore'] as int?) ?? -1).compareTo(
        (a['bestScore'] as int?) ?? -1,
      ),
    );
    final ranking = [
      for (var i = 0; i < rows.length; i++) {'rank': i + 1, ...rows[i]},
    ];
    final mine = ranking.firstWhere((r) => r['slotNumber'] == 1);
    final winner = Map<String, dynamic>.from(ranking.first)..remove('rank');
    _result = {
      'status': 'CONFIRMED',
      'roundNumber': 1,
      'myRank': mine['rank'],
      'winner': winner,
      'ranking': ranking,
      'tieBreakExplanation': null,
      'story': {
        'title': 'The Golden Chai Cup',
        'backstory':
            'A sleepy Guard watches over a cup of chai that never goes cold. '
            'The right words made him smile, and the cup changed hands.',
        'imageUrl': '',
      },
    };
    phase = 'RESULTS';
    events.add((
      'result:confirmed',
      {
        'roundId': 'rnd_1',
        'roundNumber': 1,
        'winner': winner,
        'ranking': ranking,
        'tieBreakExplanation': null,
      },
    ));
    _timers.add(Timer(const Duration(seconds: 25), close));
  }

  static void close() {
    phase = 'CLOSED';
    events.add((
      'session:closed',
      {'sessionId': 'ses_01', 'nextSessionOpened': true},
    ));
  }

  static void discard() {
    if (phase != 'PLAYING' && phase != 'RESULT_PENDING') return;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    phase = 'DISCARDED';
    events.add((
      'round:discarded',
      {'sessionId': 'ses_01', 'roundId': 'rnd_1'},
    ));
  }

  static Map<String, dynamic> result() => _result ?? {'status': 'PENDING'};

  /// GET /api/player/me
  static Map<String, dynamic> me(Map<String, dynamic> player) {
    final end = roundEnd;
    final playerState = switch (phase) {
      'PLAYING' => locked ? 'LOCKED_100' : 'PLAYING',
      'RESULT_PENDING' => 'RESULT_PENDING',
      'RESULTS' || 'CLOSED' => 'COMPLETE',
      _ => 'LOBBY',
    };
    return {
      'serverNow': DateTime.now().toUtc().toIso8601String(),
      'player': {...player, 'state': playerState, 'bestScore': best},
      'session': {
        'id': 'ses_01',
        'phase': phase,
        'capacity': 5,
        'joinedCount': end == null ? 1 : 5,
      },
      'players': [],
      'treasure': end == null ? null : treasure,
      'round': end == null
          ? null
          : {
              'roundId': 'rnd_1',
              'roundNumber': 1,
              'durationSeconds': roundSeconds,
              'startedAt': end
                  .subtract(const Duration(seconds: roundSeconds))
                  .toIso8601String(),
              'roundEndAt': end.toIso8601String(),
            },
      'prompts': prompts,
      'canSubmit':
          phase == 'PLAYING' &&
          !locked &&
          end != null &&
          DateTime.now().toUtc().isBefore(end),
    };
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
    final matches = prompts.where((e) => e['promptId'] == id);
    if (matches.isEmpty) return; // the game was reset meanwhile
    final p = matches.first;
    final lower = text.toLowerCase();
    if (lower.contains('discard')) {
      discard();
      return;
    }
    if (lower.contains('finish')) {
      endRound();
      return;
    }
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
    if (score == 100 && !locked) {
      locked = true;
      emit('player:unlocked', {
        'slotNumber': 1,
        'label': myLabel,
        'unlocked': [myLabel],
      });
    }
  }
}
