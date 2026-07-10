/// An access+refresh token pair, as returned by /api/auth/login/ and
/// /api/auth/refresh/.
class TokenPair {
  const TokenPair({required this.access, required this.refresh});

  final String access;
  final String refresh;
}
