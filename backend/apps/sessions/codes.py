"""
Join code generation.

Codes are short and human-typeable by design (per the project spec they
are treated as guessable - rate limiting on lookups happens at the view
layer, not here). Short codes mean real collision risk, so generation
retries against the DB rather than trusting randomness alone.

The listener code is a pure 6-digit numeric PIN (no language-based
prefix): it has to be readable aloud from a stage and typeable by anyone
in the room regardless of which of the six UI locales they speak, so it
carries no words in any language - same idea as a Kahoot game PIN. The
interpreter code keeps a language prefix (e.g. "EN123456") since it
identifies *which channel* the code belongs to, which is genuinely useful
information rather than decoration.
"""

import random

from apps.sessions.models import Channel, Session

_MAX_ATTEMPTS = 10
_LISTENER_CODE_DIGITS = 6
_INTERPRETER_CODE_DIGITS = 6


class CodeGenerationError(RuntimeError):
    """Raised if we can't find a free code after _MAX_ATTEMPTS tries."""


def _random_digits(n: int) -> str:
    return "".join(str(random.randint(0, 9)) for _ in range(n))


def generate_listener_code() -> str:
    for _ in range(_MAX_ATTEMPTS):
        code = _random_digits(_LISTENER_CODE_DIGITS)
        if not Session.objects.filter(listener_code=code).exists():
            return code
    raise CodeGenerationError("Could not generate a unique listener code.")


def generate_interpreter_code(language: str) -> str:
    prefix = language.upper()
    for _ in range(_MAX_ATTEMPTS):
        code = f"{prefix}{_random_digits(_INTERPRETER_CODE_DIGITS)}"
        if not Channel.objects.filter(interpreter_code=code).exists():
            return code
    raise CodeGenerationError("Could not generate a unique interpreter code.")
