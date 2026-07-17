import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/errors/api_error_message.dart';

void main() {
  group('apiErrorMessage', () {
    test('uses the server-provided message when present', () {
      final requestOptions = RequestOptions(path: '/fake/');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'code': 'INVALID_CREDENTIALS',
            'message': 'Incorrect email or password.'
          },
        ),
      );

      expect(apiErrorMessage(error), 'Incorrect email or password.');
    });

    test('gives a connectivity-specific message on timeout', () {
      final requestOptions = RequestOptions(path: '/fake/');
      final error = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
      );

      expect(
        apiErrorMessage(error),
        "Couldn't reach the server. Check your connection and try again.",
      );
    });

    test('gives a connectivity-specific message on connection error', () {
      final requestOptions = RequestOptions(path: '/fake/');
      final error = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
      );

      expect(
        apiErrorMessage(error),
        "Couldn't reach the server. Check your connection and try again.",
      );
    });

    test('falls back to a generic message for anything else', () {
      final error = StateError('boom');

      expect(apiErrorMessage(error), 'Something went wrong. Please try again.');
    });
  });
}
