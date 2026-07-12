# ADR-004: Q&A floor - raise-hand queue and floor grant

## Context

During a session's Q&A phase, listeners should be able to signal they
have a question, a guide should be able to see who's waiting and pick
one, and whoever is picked needs to actually speak - audibly, into the
source channel, so both the room and every interpreter (translating
from the source language) can hear the question.

`Session.approved_listener_uuid` has existed since the session-crud
slice specifically for this: it's the one listener currently holding
the floor. This ADR is about the queue that feeds it and the rules
around picking someone.

## Decision

**Entering Q&A mode.** A new `SessionQaModeView` (`POST
/api/sessions/<id>/qa-mode/`) reuses the existing `_SessionTransitionView`
base from session-crud, target status `QA_MODE`. Raising a hand is only
accepted while the session is in this phase - it's a distinct,
guide-controlled period, not something listeners can trigger any time
audio is playing.

**The queue.** `RaiseHandEntry` (session, listener_uuid, created_at,
unique together) is a FIFO queue. Raising a hand while already queued is
a no-op, not an error - same idempotency choice as `ListenerSession`
rejoin in ADR-002. Raising a hand requires the caller to already be a
`ListenerSession` member of this session (i.e., they've actually
joined a channel) - you can't ask a question in a room you're not in.

**Granting the floor.** `POST /api/sessions/<id>/grant-floor/` (guide,
owner-only) sets `approved_listener_uuid` to a specific listener from
the queue and removes them from it. Unlike the interpreter channel-claim
flow (ADR-003), granting the floor to someone new **implicitly replaces**
whoever held it before, rather than rejecting the call. The two
situations look similar (single-slot resource) but differ in who's
racing: channel-claim can have two interpreters independently hitting
`join` for the same code with no coordination, so a silent takeover
would leave the first one confused about why their mic stopped working.
Floor-granting has exactly one actor - the guide - making a deliberate,
sequential choice to move to the next question. There's no race to
protect against, so the simpler behavior (just replace) is correct
here, not a shortcut.

**Speaking.** `POST /api/sessions/<id>/speak/` checks
`session.approved_listener_uuid == listener_uuid` from the request and,
if it matches, returns a publisher-role Agora token for the *source*
channel (not whatever channel the listener was listening to - the
question needs to reach the room and every interpreter, not just one
language's audience). Anyone not currently holding the floor gets
`NOT_YOUR_TURN` (403). This is the same anonymous-identity authorization
model as the rest of the listener flow: knowing your own `listener_uuid`
is the only credential a listener has, so "does the UUID match" is the
whole check, same as ADR-002's join/lookup.

**Revoking.** `POST /api/sessions/<id>/revoke-floor/` (guide, owner-only)
clears `approved_listener_uuid` with no side effects on the queue -
the guide might revoke because the question's answered (queue
continues normally) or because they're ending Q&A entirely.

## Alternatives considered

- **Model the floor as its own table instead of reusing
  `approved_listener_uuid`.** Rejected - the field was already added in
  session-crud for exactly this, and a "currently active X" concept
  that's inherently one-at-a-time (like `approved_listener_uuid` or
  `ChannelInterpreter`) fits a field/one-to-one better than a table that
  would just get filtered down to "the one active row" everywhere it's
  read.
- **Reject grant-floor if someone already holds it (symmetry with
  ADR-003).** Rejected - see the "Granting the floor" reasoning above;
  the two cases aren't actually analogous once you look at who's racing.
- **Let any listener in the queue call `speak` and have the server
  pick.** Rejected - the guide needs to control pacing and ordering
  (e.g. skip someone, take a question out of order), so grant is an
  explicit guide action, not automatic queue-pop.

## Consequences

- A listener who leaves without lowering their hand stays queued until
  a guide grants or the session moves on - no listener-side heartbeat or
  timeout in this slice. Acceptable for a first version; worth revisiting
  if stale queue entries turn out to be a real annoyance in practice.
- `speak` tokens go to the source channel, so the Flutter client needs
  to know to switch its Agora engine role/channel when granted the
  floor and switch back on revoke - a client-side detail, not a backend
  one, but worth flagging for the frontend slice.
