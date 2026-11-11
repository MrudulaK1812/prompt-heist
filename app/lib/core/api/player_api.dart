import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

typedef Json = Map<String, dynamic>;
Json _json(dynamic j) => Map<String, dynamic>.from(j as Map);

class PlayerApi {
  PlayerApi(this._dio);
  final Dio _dio;

  Future<Json> joinCode(String code) => apiCall(
    () => _dio.post('/api/player/join/code', data: {'code': code}),
    _json,
  );

  Future<Json> join({
    required String joinToken,
    required String fullName,
    required String entranceId,
  }) => apiCall(
    () => _dio.post(
      '/api/player/join',
      data: {'fullName': fullName, 'entranceId': entranceId},
      options: Options(headers: {'Authorization': 'Bearer $joinToken'}),
    ),
    _json,
  );

  Future<Json> rejoin(String entranceId) => apiCall(
    () => _dio.post('/api/player/rejoin', data: {'entranceId': entranceId}),
    _json,
  );

  Future<Json> me() => apiCall(() => _dio.get('/api/player/me'), _json);

  Future<Json> submitPrompt(String text, String idempotencyKey) => apiCall(
    () => _dio.post(
      '/api/player/prompts',
      data: {'text': text},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    _json,
  );

  Future<Json> prompt(String id) =>
      apiCall(() => _dio.get('/api/player/prompts/$id'), _json);

  Future<Json> result() => apiCall(() => _dio.get('/api/player/result'), _json);
}

class DisplayApi {
  DisplayApi(this._dio);
  final Dio _dio;
  Future<Json> state() => apiCall(() => _dio.get('/api/display/state'), _json);
}

final playerApiProvider = Provider((ref) => PlayerApi(ref.watch(dioProvider)));
final displayApiProvider = Provider(
  (ref) => DisplayApi(ref.watch(dioProvider)),
);
