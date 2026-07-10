/// Ensures at most one refresh operation is in flight at a time.
///
/// Without this, N requests failing with 401 at the same moment would
/// each independently call the refresh endpoint - a thundering herd that
/// (a) wastes calls and (b) actively breaks refresh-token rotation, since
/// only the *first* of those calls would get a valid rotated token before
/// the others' refresh tokens are blacklisted out from under them.
///
/// Callers that arrive while a refresh is already running await the same
/// in-flight future instead of starting their own; once it settles
/// (success or failure), the next caller starts a fresh one.
class SingleFlightRefresh<T> {
  Future<T>? _inFlight;

  Future<T> run(Future<T> Function() action) {
    return _inFlight ??= action().whenComplete(() => _inFlight = null);
  }
}
