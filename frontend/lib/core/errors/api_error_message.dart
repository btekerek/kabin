import 'package:dio/dio.dart';

/// Every Kabin API error is {code, message} (see
/// apps/core/exceptions.py's kabin_exception_handler) with `message`
/// already a human-readable, if English-only, sentence. Screens use
/// this rather than each re-deriving a fallback for network errors
/// that never reached the server at all (timeout, no connection, etc).
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
  }
  return 'Something went wrong. Please try again.';
}
