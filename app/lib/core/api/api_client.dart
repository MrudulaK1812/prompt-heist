import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/flavor.dart';
import 'api_error.dart';
import 'mock_interceptor.dart';
import 'token_store.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Token interceptor: adds the current token unless the call set its own.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(tokenProvider);
        if (token != null && !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  if (currentFlavor == Flavor.mock) dio.interceptors.add(MockInterceptor());
  return dio;
});

/// Runs a request and throws only [ApiException] (typed error envelope).
Future<T> apiCall<T>(
  Future<Response<dynamic>> Function() request,
  T Function(dynamic json) parse,
) async {
  try {
    final res = await request();
    return parse(res.data);
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}
