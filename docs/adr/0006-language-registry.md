# ADR-006: Language registry for session content languages

## Context

`Session.source_language` and `Channel.language` (set from
`target_languages` at creation) have been free-text strings since the
very first slice - `"asdf"` is accepted today, same as `"tr"`. This
project actually has two separate i18n concerns, easy to conflate:

1. **Event content language** - what's spoken on stage and what it's
   interpreted into. This has to cover essentially any real-world
   language, since a guide could be running a conference in Japanese
   with target channels in Portuguese and Swahili; there's no fixed
   set we could reasonably hardcode.
2. **App UI language** - what language Kabin's own buttons/labels
   render in. Per the README, this is a single Dart string catalog
   (`frontend/lib/l10n/`), Turkish-only for now, with more locales
   added later via the same `app_strings` pattern. This is a Flutter
   concern with no backend involvement, and out of scope here.

This ADR is only about #1: turning "any string" into "any real
language."

## Decision

**`pycountry` as the source of truth**, not a hand-maintained list.
`apps/core/languages.py` builds `SUPPORTED_LANGUAGES` from
`pycountry.languages` filtered to entries with an `alpha_2` code - this
is exactly the ISO 639-1 set, ~184 languages, each with a real English
name (`en` -> English, `tr` -> Turkish, ...). A hand-picked list would
need a code change every time someone runs a session in a language
that wasn't anticipated; `pycountry` already has the complete standard
list and needs no maintenance as the product grows.

ISO 639-1 codes are always exactly 2 letters, so this doesn't disturb
the existing interpreter-code format (`codes.py` prefixes the code with
the channel's language, e.g. `EN123456` - see its docstring). No change
needed there.

**Validation lives in `SessionCreateSerializer`**, not a DB constraint
or model-level choices field. `validate_source_language` and
`validate_target_languages` check membership in `SUPPORTED_LANGUAGES`
(case-insensitive) and raise `KabinAPIException(code=
"UNSUPPORTED_LANGUAGE", ...)` for anything else, consistent with every
other domain error in this codebase. A `choices=` field on the model
was considered and rejected - `pycountry`'s list isn't something we'd
want copy-pasted into a migration, and validation belongs at the input
boundary (session creation), not baked into schema.

**A public `GET /api/languages/` endpoint** returns the full
`[{code, name}]` list so any future client can build a language picker
from the same source of truth the backend validates against, instead
of hardcoding its own copy. `AllowAny`, no throttle - this is static
reference data, not a guessable-secret lookup like `session-lookup`
(ADR-002), so the same risk doesn't apply.

## Alternatives considered

- **Restrict to a small curated list** (e.g. the six languages the UI
  currently supports). Rejected - conflates the two i18n axes above;
  content language and UI language have no reason to match, and this
  would block real, legitimate sessions in any language outside the
  UI's current six.
- **Validate via Django's own `LANG_INFO`.** Rejected - that table is
  scoped to languages Django ships *its own* translations for, which
  is a coincidental and incomplete subset of real-world languages, not
  an authoritative language registry.

## Consequences

- New dependency: `pycountry` (data-only, no runtime behavior beyond
  the lookup table - negligible maintenance cost).
- `source_language`/`target_languages` now reject garbage input at
  session creation instead of silently accepting it, closing the one
  remaining data-integrity gap in session creation.
- The `/api/languages/` endpoint gives the eventual Flutter session
  creation screen a real list to build a picker from, rather than that
  screen needing to invent or hardcode one when it's built.
