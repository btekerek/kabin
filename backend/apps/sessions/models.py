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
Session.can_transition_to). Message and RaiseHandEntry belong to later
slices (chat, Q&A) and intentionally aren't here yet.

ListenerSession tracks anonymous listener joins (see ADR-002) - one row
per (session, listener_uuid), used to enforce the listener cap and to
let a listener switch channels without losing/re-spending their spot.

ChannelInterpreter tracks which interpreter currently owns a channel
(see ADR-003) - one row per channel, since exactly one interpreter may
broadcast into a channel at a time.
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

    @property
    def agora_channel_name(self) -> str:
        """Stable, opaque Agora channel identity - see ADR-002."""
        return f"kabin-ch-{self.id}"


class ListenerSession(models.Model):
    """One row per listener who has ever joined a session (see ADR-002).

    `channel` is which language they're currently listening to; joining
    again with the same `listener_uuid` updates this row rather than
    creating a new one, so switching channels doesn't cost the listener
    a second seat against the session's listener cap.
    """

    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name="listener_sessions")
    listener_uuid = models.UUIDField()
    channel = models.ForeignKey(Channel, on_delete=models.CASCADE, related_name="+")
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["session", "listener_uuid"], name="unique_listener_per_session"
            )
        ]

    def __str__(self):
        return f"{self.listener_uuid} in {self.session_id} ({self.channel.language})"


class ChannelInterpreter(models.Model):
    """The interpreter currently broadcasting into a channel (see ADR-003).

    `channel` is a OneToOneField, not a ForeignKey: exactly one
    interpreter may hold a channel at a time. Claiming/releasing is
    handled in the join/leave views, not here.
    """

    channel = models.OneToOneField(
        Channel, on_delete=models.CASCADE, related_name="interpreter_claim"
    )
    interpreter = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="channel_claims"
    )
    joined_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.interpreter} on {self.channel}"
