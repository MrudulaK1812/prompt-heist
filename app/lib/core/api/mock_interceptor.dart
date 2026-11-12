import 'package:dio/dio.dart';

/// Answers the contract endpoints locally in the mock flavour.
/// Booth codes: "12" works, "99" is claimed, "00" = no open session.
/// Entrance ID "USED" / "DUP" give the matching errors, "NONE" = NO_ACTIVE_GAME.
class MockInterceptor extends Interceptor {
  String _myLabel = 'Aman';

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
        if ((body['entranceId'] ?? '') == 'NONE') {
          return fail(
            404,
            'NO_ACTIVE_GAME',
            'No active game found for that ID.',
          );
        }
        return ok({'playerToken': 'mock-player-token-2', 'player': _player()});

      case 'GET /api/player/me':
        return ok({
          'serverNow': DateTime.now().toUtc().toIso8601String(),
          'player': {..._player(), 'bestScore': null},
          'session': {
            'id': 'ses_01',
            'phase': 'JOINING',
            'capacity': 5,
            'joinedCount': 1,
          },
          'players': [],
          'treasure': null,
          'round': null,
          'prompts': [],
          'canSubmit': false,
        });

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
