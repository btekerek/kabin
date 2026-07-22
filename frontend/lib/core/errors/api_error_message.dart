import 'package:dio/dio.dart';

/// Every Kabin API error is {code, message} (see
/// apps/core/exceptions.py's kabin_exception_handler) with `message`
/// already a human-readable, if English-only, sentence. Screens use
/// this rather than each re-deriving a fallback for network errors
/// that never reached the server at all (timeout, no connection, etc).
///
/// Connectivity failures (timeout, connection refused/error) get their
/// own message rather than falling into the generic one - "couldn't
/// reach the server" points at the network/backend, where "something
/// went wrong" reads as "retry and hope," which wastes the user's time
/// on a class of failure retrying can't fix.
String apiErrorMessage(Object error) {
  // Some screens (e.g. CreateSessionScreen's client-side validation)
  // stash a plain String as their "error" alongside real caught
  // exceptions, so the same _submitError field and display line can
  // handle both - without this branch, a String error always fell
  // through to the generic fallback below instead of showing itself.
  if (error is String) return error;
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (_isConnectivityFailure(error.type)) {
      return "Couldn't reach the server. Check your connection and try again.";
    }
  }
  return 'Something went wrong. Please try again.';
}

bool _isConnectivityFailure(DioExceptionType type) {
  switch (type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    default:
      return false;
  }
}
