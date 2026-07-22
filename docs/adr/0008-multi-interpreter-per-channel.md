# ADR-008: Multiple interpreters per channel

## Context

ADR-003 made `ChannelInterpreter` one-row-per-channel: a second
interpreter joining an already-claimed channel got `CHANNEL_ALREADY_STAFFED`.
In practice, teams want a backup or relief interpreter able to join the
same channel and stand by - not be locked out until the first one
disconnects.

## Decision

`ChannelInterpreter.channel` is now a `ForeignKey`, not a
`OneToOneField`, with a `unique(channel, interpreter)` constraint
instead. Joining a channel always succeeds:

- No existing claim for this interpreter -> create one.
- Existing claim for this interpreter -> no-op, fresh token (reconnect).
- Existing claim(s) for other interpreters -> unaffected; this
  interpreter gets their own claim alongside them.

`CHANNEL_ALREADY_STAFFED` is removed. Any interpreter with a valid claim
can request a publisher token and start broadcasting at any time -
nothing on the server arbitrates who's actually live. If two
interpreters both unmute, both are heard; the client is expected to warn
before letting someone unmute into an already-occupied channel (see
BigMicButton/session dashboard).

## Consequences

- No server-side notion of "who's currently live" on a channel - that
  signal has to come from the client (Agora's own remote-user/publish
  events), not from `ChannelInterpreter` row state.
- `ChannelLeaveView` is unaffected: it already deleted only the calling
  interpreter's own claim, which still works unchanged under the FK.
