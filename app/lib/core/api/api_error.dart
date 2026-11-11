import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.correlationId,
    this.statusCode,
  });

  final String code; // e.g. ROUND_EXPIRED, CODE_INVALID
  final String message; // safe text for the user
  final String? correlationId;
  final int? statusCode;

  bool get isNetwork => code == 'NETWORK_ERROR';

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    final data = res?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        code: err['code']?.toString() ?? 'UNKNOWN',
        message: err['message']?.toString() ?? 'Something went wrong.',
        correlationId:
            err['correlationId']?.toString() ??
            res?.headers.value('x-correlation-id'),
        statusCode: res?.statusCode,
      );
    }
    return ApiException(
      code: 'NETWORK_ERROR',
      message: 'Cannot reach the server. Check your connection.',
      statusCode: res?.statusCode,
    );
  }

  @override
  String toString() => 'ApiException($code, $statusCode)';
}
