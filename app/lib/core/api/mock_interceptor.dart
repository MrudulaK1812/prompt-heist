import 'package:dio/dio.dart';

import '../mock/mock_world.dart';

/// Answers the contract endpoints locally in the mock flavour.
/// Booth codes: "12" works, "99" is claimed, "00" = no open session.
/// Entrance ID "USED" / "DUP" give the matching errors.
/// Rejoin IDs: NONE, MANY, PLAYING, LOCKED, PENDING, DONE.
/// Prompt words: "block", "fail", "unlock" (=100), "offline" (fails once, then works on retry).
class MockInterceptor extends Interceptor {
  String _myLabel = 'Aman';
  final _offlineOnce = <String>{};

  Map<String, dynamic> _player() => {
    'id': 'ply_1',
    'slotNumber': 1,
    'label': _myLabel,
    'shape': 'BLUE_CIRCLE',
    'state': 'LOBBY',
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final body = options.data is Map ? options.data as Map : const {};
    final key = '${options.method} ${options.path}';

    void ok(Object data, [int status = 200]) => handler.resolve(
      Response(
        requestOptions: options,
        statusCode: status,
        data: data,
        headers: Headers.fromMap({
          'x-correlation-id': ['mock-1'],
        }),
      ),
    );

    void fail(int status, String code, String message) => handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: status,
          data: {
            'error': {
              'code': code,
              'message': message,
              'correlationId': 'mock-1',
            },
          },
        ),
      ),
    );
    // API 25: GET /api/player/prompts/:id (fallback if a socket event is missed)
    if (options.method == 'GET' &&
        options.path.startsWith('/api/player/prompts/')) {
      final pid = options.path.split('/').last;
      final found = MockWorld.prompts.where((e) => e['promptId'] == pid);
      if (found.isEmpty) return fail(404, 'NOT_FOUND', 'Prompt not found.');
      final p = found.first;
      return ok({
        'promptId': pid,
        'status': p['status'],
        'score': p['score'],
        'feedback': p['feedback'],
        'message': p['message'],
        'receivedAt': p['receivedAt'],
        'sequence': p['sequence'],
      });
    }

    switch (key) {
      case 'POST /api/player/join/code':
        final code = body['code'];
        if (code == '12') {
          return ok({
            'joinToken': 'mock-join-token',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
            'slot': {'slotNumber': 1, 'capacity': 5, 'shape': 'BLUE_CIRCLE'},
          });
        }
        if (code == '99') {
          return fail(
            409,
            'CODE_ALREADY_CLAIMED',
            'That code is already taken.',
          );
        }
        if (code == '00') {
          return fail(409, 'NO_ACTIVE_SESSION', 'No game is open right now.');
        }
        return fail(404, 'CODE_INVALID', 'That code is not valid.');

      case 'POST /api/player/join':
        final name = (body['fullName'] ?? '').toString().trim();
        final id = (body['entranceId'] ?? '').toString().trim();
        if (name.isEmpty) {
          return fail(422, 'NAME_REQUIRED', 'Please enter your name.');
        }
        if (id.isEmpty) {
          return fail(
            422,
            'ENTRANCE_ID_REQUIRED',
            'Please enter your entrance ID.',
          );
        }
        if (id == 'USED') {
          return fail(
            409,
            'ENTRANCE_ID_USED',
            'This entrance ID has already played.',
          );
        }
        if (id == 'DUP') {
          return fail(
            409,
            'ENTRANCE_ID_IN_SESSION',
            'This entrance ID is already in this game.',
          );
        }
        _myLabel = name.split(' ').first;
        return ok({
          'playerToken': 'mock-player-token',
          'player': _player(),
        }, 201);

      case 'POST /api/player/rejoin':
        final rid = (body['entranceId'] ?? '').toString().trim();
        if (rid == 'NONE') {
          return fail(
            404,
            'NO_ACTIVE_GAME',
            'No active game found for that ID.',
          );
        }
        if (rid == 'MANY') {
          return fail(
            429,
            'TOO_MANY_ATTEMPTS',
            'Too many attempts. Try again in a minute.',
          );
        }
        const restored = {
          'PLAYING': 'PLAYING',
          'LOCKED': 'LOCKED_100',
          'PENDING': 'RESULT_PENDING',
          'DONE': 'COMPLETE',
        };
        return ok({
          'playerToken': 'mock-player-token-2',
          'player': {..._player(), 'state': restored[rid] ?? 'LOBBY'},
        });

      case 'GET /api/player/me':
        final mEnd = MockWorld.roundEnd;
        final playing = mEnd != null;
        return ok({
          'serverNow': DateTime.now().toUtc().toIso8601String(),
          'player': {
            ..._player(),
            'state': playing ? 'PLAYING' : 'LOBBY',
            'bestScore': MockWorld.best,
          },
          'session': {
            'id': 'ses_01',
            'phase': playing ? 'PLAYING' : 'JOINING',
            'capacity': 5,
            'joinedCount': playing ? 5 : 1,
          },
          'players': [],
          'treasure': playing ? MockWorld.treasure : null,
          'round': playing
              ? {
                  'roundId': 'rnd_1',
                  'roundNumber': 1,
                  'durationSeconds': MockWorld.roundSeconds,
                  'startedAt': mEnd
                      .subtract(const Duration(seconds: MockWorld.roundSeconds))
                      .toIso8601String(),
                  'roundEndAt': mEnd.toIso8601String(),
                }
              : null,
          'prompts': MockWorld.prompts,
          'canSubmit': playing && DateTime.now().toUtc().isBefore(mEnd),
        });

      case 'POST /api/player/prompts':
        final ptext = (body['text'] ?? '').toString().trim();
        final pkey = options.headers['Idempotency-Key']?.toString() ?? '';
        if (pkey.isEmpty) {
          return fail(400, 'IDEMPOTENCY_KEY_REQUIRED', 'Missing key.');
        }
        if (ptext.isEmpty) {
          return fail(422, 'PROMPT_EMPTY', 'Write something first.');
        }
        if (ptext.length > 200) {
          return fail(422, 'PROMPT_TOO_LONG', 'That prompt is too long.');
        }
        final pend = MockWorld.roundEnd;
        if (pend == null) {
          return fail(409, 'ROUND_NOT_PLAYING', 'No round is running.');
        }
        if (DateTime.now().toUtc().isAfter(pend)) {
          return fail(409, 'ROUND_EXPIRED', 'Time is up.');
        }
        // Word "offline": the first try fails like a dropped network.
        if (ptext.toLowerCase().contains('offline') && _offlineOnce.add(pkey)) {
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
        }
        final (isNew, record) = MockWorld.submit(ptext, pkey);
        return ok(record, isNew ? 202 : 200);

      case 'GET /api/display/state':
        return ok({
          'serverNow': DateTime.now().toUtc().toIso8601String(),
          'phase': 'JOINING',
          'joinUrl': 'heist.devfestpune.dev',
          'session': {'capacity': 5, 'joinedCount': 3},
          'players': [],
          'treasure': null,
          'round': null,
          'unlocked': [],
          'result': null,
        });
    }
    fail(404, 'NOT_FOUND', 'Not found in mock: $key');
  }
}
