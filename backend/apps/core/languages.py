"""
Registry of supported event content languages (see ADR-006).

This is deliberately NOT the same thing as the app's own UI language
(Turkish-only for now, via frontend/lib/l10n/ - see the README). This
registry is about what languages a session can be spoken in and
interpreted into, which has to cover essentially any real-world
language.

Built from pycountry's ISO 639-1 table rather than hand-maintained, so
it never needs a code change to support a language that already has a
real 2-letter code. Language codes are always exactly 2 letters, which
matches the existing interpreter-code format (see apps/sessions/codes.py).
"""

import pycountry

SUPPORTED_LANGUAGES: dict[str, str] = {
    language.alpha_2.upper(): language.name
    for language in pycountry.languages
    if hasattr(language, "alpha_2")
}


def is_supported_language(code: str) -> bool:
    return bool(code) and code.upper().strip() in SUPPORTED_LANGUAGES


def language_list() -> list[dict[str, str]]:
    """Sorted [{code, name}] list for API responses."""
    return [
        {"code": code, "name": name}
        for code, name in sorted(SUPPORTED_LANGUAGES.items(), key=lambda item: item[1])
    ]
