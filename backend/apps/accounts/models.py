"""
Accounts app: Guide and Interpreter user accounts.

Listeners are NOT Django users (they're anonymous, identified by a
client-generated UUID persisted in shared_preferences) so they don't live
here - see apps.sessions.models.SessionListener instead.

Login identifies a user by email (see EmailTokenObtainPairSerializer),
not the inherited `username` field. We keep `username` (from AbstractUser)
internally - auto-generated at registration, never shown to the user -
rather than doing a destructive swap to AbstractBaseUser, since Django
still needs *some* USERNAME_FIELD-independent unique field for admin/
internal use. `email` is the field users and the API actually care about.

`role` is blank-able at the DB level (default "") purely so this migration
doesn't need an interactive one-off default; it's enforced as required at
the API level instead, in RegisterSerializer.
"""

from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    class Role(models.TextChoices):
        GUIDE = "guide", "Guide"
        INTERPRETER = "interpreter", "Interpreter"

    email = models.EmailField("email address", unique=True)
    role = models.CharField(max_length=20, choices=Role.choices, blank=True, default="")

    def __str__(self):
        return f"{self.email} ({self.role})"
