# ADR-001: Dual-token JWT authentication (short-lived access + rotating refresh)

## Context

Guides and Interpreters have accounts and need to authenticate against the
Django API from a mobile client. Listeners are anonymous and out of scope
for this ADR (see `SessionListener` / client-generated UUID instead).

A JWT's core property: the server verifies it by recomputing an HMAC
signature over the header+payload using a secret only the server knows.
No database lookup is needed to accept a request — which also means a
single JWT cannot be revoked early. Once issued, it's valid until it
expires, full stop. Any security design built on JWTs has to work within
that constraint rather than against it.

## Decision

Two tokens, issued together at login:

- **Access token** — 15 minute lifetime. Sent on every API request via
  `Authorization: Bearer <token>`. Verified statelessly (signature check
  only, no DB hit).
- **Refresh token** — 7 day lifetime. Used only to mint a new access
  token. `ROTATE_REFRESH_TOKENS=True`: every refresh call returns a new
  refresh token alongside the new access token. `BLACKLIST_AFTER_ROTATION
  =True`: the refresh token just used is immediately blacklisted server-
  side (`rest_framework_simplejwt.token_blacklist`), so it cannot be used
  a second time.

Because a JWT can't be revoked early, the access token's 15-minute
lifetime is the entire blast radius of a leaked access token. The refresh
token's rotation means a leaked refresh token is only usable once — if an
attacker uses it before the legitimate user does, the legitimate user's
next refresh fails (their copy was already spent), which is a detectable
signal that forces re-authentication.

Storage on the Flutter client: access token in memory only. Refresh token
in `flutter_secure_storage` (Android Keystore / iOS Keychain-backed,
encrypted at rest) — not `shared_preferences`, which is unencrypted and
reserved for the listener UUID (not a credential).

Client flow on 401: a single Dio interceptor attaches the access token to
outgoing requests. On a 401, it triggers a refresh (deduplicated — only
one refresh call in flight at a time; other 401s queue behind it),
retries the original request(s) with the new access token, and only
routes to the login screen if the refresh call *itself* fails (refresh
token expired or blacklisted).

## Alternatives considered

- **Django session-cookie auth.** Doesn't map cleanly onto a mobile
  client's request lifecycle, and the project has an explicit requirement
  for dual-token JWT regardless.
- **Single long-lived token, no refresh.** Forces a bad tradeoff: short
  lifetime means constant re-logins, long lifetime means a large blast
  radius if the token leaks.
- **Non-rotating refresh token.** Simpler (no blacklist bookkeeping), but
  a stolen refresh token stays silently valid for its full lifetime with
  no way to detect the theft.

## Consequences

- Every API client needs refresh-retry logic; this is centralized in one
  Dio interceptor so feature code never has to think about it.
- The blacklist needs a real table (`token_blacklist` app) and grows with
  every refresh — acceptable at this scale, worth revisiting if refresh
  volume ever gets large enough to warrant periodic pruning.
- Access tokens are stateless: revoking a compromised *access* token early
  isn't possible. The mitigation is its short lifetime, not revocation.
- A stolen refresh token is only usable once before the legitimate user's
  next refresh reveals the compromise — but that detection only fires the
  *next* time the legitimate client tries to refresh, not immediately.
