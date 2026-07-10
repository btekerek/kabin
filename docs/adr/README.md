# Architecture Decision Records

One page per significant technical decision: context, decision,
consequences. Written so any of them could be read aloud in a meeting and
used to defend the choice.

Numbering starts at ADR-001 (dual-token JWT auth: access + rotating
refresh, blacklist-after-rotation), written alongside the first feature
slice. Add one file per decision as the project grows, e.g.:

- 0001-auth-strategy.md
- 0002-qa-into-source-channel.md
- 0003-open-mic-model.md

Template for each ADR:

    # ADR-00N: <title>

    ## Context
    What problem are we solving? What constraints apply?

    ## Decision
    What we chose, in plain language.

    ## Alternatives considered
    What else we looked at, and why we didn't pick it.

    ## Consequences
    What this makes easier, what it makes harder, what to watch for.
