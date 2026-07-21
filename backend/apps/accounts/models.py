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

from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    email = models.EmailField("email address", unique=True)

    def __str__(self):
        return self.email
