"""
Accounts app: user accounts for anyone who logs in.

There is no fixed account role. Any authenticated user can create a
session (becoming that session's owner - the "guide" for it) and/or
claim an interpreter channel on any session (becoming an "interpreter"
for that channel) - see apps.sessions.permissions.IsSessionOwner and
apps.sessions.models.ChannelInterpreter. "Guide" and "Interpreter" are
therefore per-action, per-session relationships derived from ownership/
claims, not a property of the account itself.

Listeners are NOT Django users (they're anonymous, identified by a
client-generated UUID persisted in shared_preferences) so they don't live
here - see apps.sessions.models.SessionListener instead.

A user picks their own `username` (from AbstractUser) at registration -
unlike the historical Django convention, it's not the primary login
identifier by itself. LoginSerializer accepts either `email` or
`username` interchangeably; `email` additionally has a reserved role for
account recovery (password reset), which is why it stays mandatory and
unique alongside username. `username` is also what's shown as the chat
sender's name instead of a generic "Guide"/"Interpreter" label or the
user's email (see MessageSerializer.sender_name).
"""

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    email = models.EmailField("email address", unique=True)

    def __str__(self):
        return self.email


class EmailVerificationCode(models.Model):
    """The one pending 6-digit code for a not-yet-verified user.

    Registration creates the user with is_active=False (the same flag
    LoginSerializer already checks, so an unverified account simply can't
    log in yet - no separate "verified" field needed) and one of these
    rows alongside it. `code` is overwritten in place on resend, so
    there's only ever one valid code per user at a time - same idea as
    codes.py's short human-typeable codes, just scoped to one user
    instead of needing global uniqueness.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="email_verification"
    )
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"verification code for {self.user_id}"
