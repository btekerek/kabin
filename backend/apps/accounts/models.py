"""
Accounts app: Guide and Interpreter user accounts.

Listeners are NOT Django users (they're anonymous, identified by a
client-generated UUID persisted in shared_preferences) so they don't live
here — see apps.sessions.models.SessionListener instead.

This is a bare AbstractUser stub for now. AUTH_USER_MODEL must point at a
custom model from the project's first migration (swapping it later means
a destructive reset), but the actual fields/roles are added in the auth
slice, along with the first migration.
"""

from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    pass
