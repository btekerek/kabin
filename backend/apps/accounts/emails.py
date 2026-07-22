"""
Email-verification code generation and delivery.

Kept local to this app rather than reusing apps.sessions.codes -
that module's codes need global DB-uniqueness (they're looked up by
value across all channels/sessions); a verification code only ever
needs to be unique per-user (see EmailVerificationCode's OneToOne), so
there's nothing to share beyond "N random digits".
"""

import random

from django.conf import settings
from django.core.mail import send_mail

_CODE_DIGITS = 6


def generate_verification_code() -> str:
    return "".join(str(random.randint(0, 9)) for _ in range(_CODE_DIGITS))


def send_verification_email(user, code: str) -> None:
    """fail_silently=False is deliberate - a registration whose
    verification email silently never sent would strand the user with
    an account they can't activate, and nothing in the UI to explain
    why. Let the SMTP error surface as a 500 instead.
    """
    send_mail(
        subject="Your Kabin verification code",
        message=(
            f"Your Kabin verification code is {code}.\n\n"
            f"It expires in {settings.EMAIL_VERIFICATION_TTL_MINUTES} minutes."
        ),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        fail_silently=False,
    )
