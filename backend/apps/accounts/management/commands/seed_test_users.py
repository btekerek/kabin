"""
Wipes every user and replaces them with a fixed set of 5 test accounts.

There's no fixed account role (see accounts app docstring) - any user can
be a guide or an interpreter - so a handful of interchangeable test
accounts is enough to exercise every role during manual testing.

Deleting a user cascades to everything owned by it (their sessions,
channel claims, sent messages - see models.py's on_delete=CASCADE), so
this is a full reset, not just an accounts wipe.
"""

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.accounts.models import User

_TEST_USERS = [
    {"email": f"test{n}@gmail.com", "username": f"test{n}", "password": f"test{n}test{n}"}
    for n in range(1, 6)
]


class Command(BaseCommand):
    help = "Deletes all users (and everything they own) and recreates 5 fixed test accounts."

    def handle(self, *args, **options):
        with transaction.atomic():
            total_deleted, _ = User.objects.all().delete()
            for data in _TEST_USERS:
                User.objects.create_user(
                    email=data["email"],
                    username=data["username"],
                    password=data["password"],
                )

        self.stdout.write(
            self.style.SUCCESS(
                f"Deleted {total_deleted} row(s) (users + everything cascaded from them)."
            )
        )
        for data in _TEST_USERS:
            self.stdout.write(f"  {data['email']} / {data['username']} / {data['password']}")
