import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/core/api/api_error.dart';

void main() {
  test('maps the error envelope to ApiException', () {
    final ro = RequestOptions(path: '/x');
    final e = DioException(
      requestOptions: ro,
      response: Response(
        requestOptions: ro,
        statusCode: 404,
        data: {
          'error': {
            'code': 'CODE_INVALID',
            'message': 'nope',
            'correlationId': 'c1',
          },
        },
      ),
    );
    final a = ApiException.fromDio(e);
    expect(a.code, 'CODE_INVALID');
    expect(a.correlationId, 'c1');
    expect(a.statusCode, 404);
  });

  test('no response means a network error', () {
    final e = DioException(requestOptions: RequestOptions(path: '/x'));
    expect(ApiException.fromDio(e).isNetwork, isTrue);
  });
}
