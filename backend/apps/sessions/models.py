"""
Sessions app: the core event domain.

A Session belongs to one Guide and always has exactly one source Channel
(is_source=True, the stage feed) plus one or more target Channels. Both
the session's listener_code and each channel's interpreter_code are short,
human-typeable join codes - deliberately guessable, per the project spec,
so lookups must be rate-limited (that's enforced at the view layer, not
here).

Status is a small state machine, not a free-form field: not_started ->
active <-> qa_mode -> ended, with ended treated as genuinely terminal (see
Session.can_transition_to). ChannelInterpreter, Message, RaiseHandEntry,
and SessionListener belong to later slices (interpreter assignment, chat,
Q&A) and intentionally aren't here yet.
"""

from django.conf import settings
from django.db import models


class Session(models.Model):
    class Status(models.TextChoices):
        NOT_STARTED = "not_started", "Not started"
        ACTIVE = "active", "Active"
        QA_MODE = "qa_mode", "Q&A"
        ENDED = "ended", "Ended"

    # Legal transitions, enforced server-side so a client bug can never
    # walk a session back out of "ended".
    _ALLOWED_TRANSITIONS = {
        Status.NOT_STARTED: {Status.ACTIVE},
        Status.ACTIVE: {Status.QA_MODE, Status.NOT_STARTED, Status.ENDED},
        Status.QA_MODE: {Status.ACTIVE, Status.NOT_STARTED, Status.ENDED},
        Status.ENDED: set(),
    }

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="sessions"
    )
    name = models.CharField(max_length=200)
    source_language = models.CharField(max_length=10)
    listener_code = models.CharField(max_length=20, unique=True, db_index=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.NOT_STARTED)
    approved_listener_uuid = models.UUIDField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.name} ({self.status})"

    def can_transition_to(self, new_status: str) -> bool:
        return new_status in self._ALLOWED_TRANSITIONS.get(self.status, set())


class Channel(models.Model):
    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name="channels")
    language = models.CharField(max_length=10)
    interpreter_code = models.CharField(max_length=20, unique=True, db_index=True)
    is_source = models.BooleanField(default=False)

    class Meta:
        indexes = [models.Index(fields=["session"])]
        ordering = ["-is_source", "language"]

    def __str__(self):
        return f"{self.language} ({'source' if self.is_source else 'target'})"
