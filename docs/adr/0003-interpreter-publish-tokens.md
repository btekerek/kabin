# ADR-003: Interpreter channel claiming + publish tokens

## Context

Interpreters are real Django accounts (role=`interpreter`), unlike
listeners. Each `Channel` already has a unique `interpreter_code` (e.g.
`EN482139`) generated at session-creation time (ADR-002's sibling
decision from the session-crud slice). An interpreter who has that code
needs to start broadcasting into the channel's Agora room - the
publish-side counterpart to the listener's subscribe-side flow from
ADR-002.

Two channels should never be double-staffed by two different people
talking over each other, but the same interpreter reconnecting (app
restart, dropped connection) shouldn't be treated as a conflict.

## Decision

**Channel claiming.** `ChannelInterpreter` is a one-row-per-channel model
(`channel` as `OneToOneField`, `interpreter` FK to `User`, `joined_at`).
Joining a channel is "claim if free, refresh if it's already yours,
reject if someone else has it":

- No existing claim -> create one for this interpreter.
- Existing claim, same interpreter -> no-op, just issue a fresh token
  (covers reconnects).
- Existing claim, different interpreter -> `CHANNEL_ALREADY_STAFFED`
  (409). No silent takeover - a guide/admin action to boot an
  interpreter is a later concern, not implicit in a second person typing
  the same code.

**Leaving.** `POST /api/channels/leave/` (also code-based) deletes the
calling interpreter's own claim. It's a no-op (not an error) if they
don't currently hold it, since "leave" should be safe to call
defensively from the client without checking state first.

**No lookup step.** Unlike the listener flow, there's no separate
"lookup by code" call before joining. A listener's PIN identifies a
whole session with multiple channels to choose from; an interpreter's
code already identifies one specific channel. Join is a single call.

**Token role and identity.** `Role_Publisher`, identified by the
interpreter's Django user id (`str(user.id)`) as the Agora account -
reusing the same `agora.py` module and `Channel.agora_channel_name`
scheme from ADR-002, just a different role and a different identity
source (authenticated user id instead of an anonymous UUID).

**No public throttle.** The listener lookup/join endpoints needed
`ScopedRateThrottle` because they're anonymous and PIN-guessable
(ADR-002). This endpoint requires a real, authenticated Interpreter
account - creating an account is a much higher bar than guessing six
digits, so no additional throttle is added here. If interpreter-code
brute-forcing by registered-but-malicious accounts turns out to be a
real problem, that's a rate-limit-per-user concern to revisit later, not
a per-IP one.

## Alternatives considered

- **Allow multiple interpreters per channel (backup/relief roster).**
  Rejected for this slice - real, but it's a scheduling feature layered
  on top of "who is live right now," not a prerequisite for the first
  working audio path. `ChannelInterpreter` as a one-to-one keeps this
  slice's scope to "exactly one live broadcaster."
- **Let a second interpreter silently bump the first.** Rejected -
  Agora would then have two publishers racing, and the bumped
  interpreter would have no idea they'd lost the channel until their
  audio silently stopped mattering.

## Consequences

- Taking a channel back from a stale claim (interpreter's app crashed
  without calling `leave`) requires either the same interpreter
  rejoining (allowed - it's their own claim) or a future guide-initiated
  "force release" action. Not built yet; today a stuck claim blocks
  other interpreters until the original interpreter reconnects.
- `agora.py` now has one function per role rather than a single
  parameterized one - slightly more code, but keeps each function's
  signature obviously tied to one specific security posture (audience
  vs. publisher) rather than a `role` flag callers could pass wrong.
