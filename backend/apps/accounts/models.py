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

Login identifies a user by email (see EmailTokenObtainPairSerializer),
not the inherited `username` field. We keep `username` (from AbstractUser)
internally - auto-generated at registration, never shown to the user -
rather than doing a destructive swap to AbstractBaseUser, since Django
still needs *some* USERNAME_FIELD-independent unique field for admin/
internal use. `email` is the field users and the API actually care about.
"""

from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    email = models.EmailField("email address", unique=True)

    def __str__(self):
        return self.email
