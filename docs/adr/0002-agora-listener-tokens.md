# ADR-002: Agora channel naming + listener token strategy

## Context

Listeners are anonymous (no Django account — identified by a client-
generated UUID persisted in `shared_preferences`). They join a session by
typing its 6-digit PIN, then pick a language channel to listen to. To
actually receive audio they need an Agora RTC token scoped to that
channel. Interpreters will need to *publish* to these same channels in
the next slice, so the naming/token scheme has to work for both roles
from the start even though only the listener (subscribe) side is built
now.

## Decision

**Channel naming.** Each `Channel` row gets a stable, opaque Agora channel
name: `kabin-ch-<channel.id>`. It's derived from the DB primary key, not
from the join code, so rotating/regenerating a join code later (not
supported today, but plausible) never has to touch the Agora channel
identity.

**Token role.** Listeners get a `Role_Subscriber` (audience) token — they
can receive audio but the Agora SDK will reject any attempt from that
token to publish. This is enforced by Agora itself, not just client-side
convention, so a compromised or reverse-engineered client still can't
inject audio into a channel it's only supposed to listen to.

**Token identity.** The token is built with the listener's UUID as the
Agora "account" (`buildTokenWithAccount`), not a numeric uid. This keeps
the listener's client-generated UUID as the single identity used
everywhere (join tracking, Agora presence), rather than inventing a
second identifier.

**Token TTL.** 1 hour (`AGORA_TOKEN_TTL_SECONDS`, default 3600), issued
fresh on every `join` call. A listener whose token expires mid-session
just calls `join` again — cheap, and avoids needing a separate
token-refresh endpoint for this slice.

**Listener cap.** A `ListenerSession` row (session, listener_uuid,
channel, joined_at) is created on first join. The cap
(`SESSION_LISTENER_CAP_DEFAULT`) is enforced by counting distinct
`ListenerSession` rows for the session, not Agora's own presence API —
Agora presence is eventually-consistent and per-channel, and we need an
exact, per-session count. Rejoining with the same UUID (e.g. switching
languages) updates the existing row instead of creating a new one, so
switching channels never costs the listener their spot.

**Lookup is public but throttled.** `POST /sessions/lookup/` (PIN ->
session + channel list) requires no auth, since listeners aren't Django
users. Per the existing note in `codes.py`, short PINs are guessable by
design, so this endpoint is the one place that risk becomes real: it's
rate-limited via DRF's `ScopedRateThrottle` (`session-lookup` scope,
20/min per IP).

## Alternatives considered

- **Numeric Agora uid instead of account string.** Would need a second
  mapping table from listener UUID -> uid; the account-string API avoids
  that for a negligible token-size cost.
- **Cap enforcement via Agora's channel presence/RTM.** Rejected — it's
  per-channel and eventually consistent, not per-session and exact, and
  we'd still need our own row to support idempotent channel-switching.
- **Long-lived listener tokens (issued once, valid for the whole
  event).** Rejected — Agora tokens are also bearer credentials; keeping
  the TTL short limits the blast radius of a leaked token the same way
  ADR-001 limits the blast radius of a leaked access token.

## Consequences

- Interpreter publish tokens (next slice) reuse the same
  `kabin-ch-<id>` naming and `agora.py` builder, just with
  `Role_Publisher` and the interpreter's own identity — no new naming
  scheme needed.
- Every `join` call hits Agora's token builder (cheap, local HMAC-style
  signing, no network call) plus one DB write/update — fine at this
  scale.
- `SESSION_LISTENER_CAP_DEFAULT` is enforced at the application layer,
  so it's exact but does mean a hot session's join endpoint takes a
  `count()` query on every call; worth revisiting with a cached counter
  if listener churn ever gets heavy.
