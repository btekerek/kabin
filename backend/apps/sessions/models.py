from django.conf import settings
from django.db import models


class Session(models.Model):
    class Status(models.TextChoices):
        NOT_STARTED = "not_started", "Not started"
        ACTIVE = "active", "Active"
        ENDED = "ended", "Ended"

    # Legal transitions, enforced server-side so a client bug can never
    # walk a session back out of "ended". not_started -> ended is allowed
    # so a session that's never gone live can still be ended/cancelled.
    _ALLOWED_TRANSITIONS = {
        Status.NOT_STARTED: {Status.ACTIVE, Status.ENDED},
        Status.ACTIVE: {Status.NOT_STARTED, Status.ENDED},
        Status.ENDED: set(),
    }

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="sessions"
    )
    name = models.CharField(max_length=200)
    source_language = models.CharField(max_length=10)
    listener_code = models.CharField(max_length=20, unique=True, db_index=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.NOT_STARTED)
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
    # Null for the source channel: nobody joins the source with a code -
    # listeners join the whole session via the listener PIN, and
    # interpreters join their own target channel via its code. Only
    # target (is_source=False) channels ever get one.
    interpreter_code = models.CharField(
        max_length=20, unique=True, db_index=True, null=True, blank=True
    )
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


class Message(models.Model):
    """A single chat message (see ADR-005).

    `sender_kind` discriminates which of `sender` (guide/interpreter,
    a real User) or `sender_listener_uuid` (listener, anonymous) is
    populated - exactly one of the two, matching whichever identity
    model that sender kind uses everywhere else in this app.
    """

    class SenderKind(models.TextChoices):
        GUIDE = "guide", "Guide"
        INTERPRETER = "interpreter", "Interpreter"
        LISTENER = "listener", "Listener"

    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name="messages")
    sender_kind = models.CharField(max_length=20, choices=SenderKind.choices)
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="sent_messages",
    )
    sender_listener_uuid = models.UUIDField(null=True, blank=True)
    body = models.TextField(max_length=2000)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]

    def __str__(self):
        return f"{self.sender_kind} message in {self.session_id}"
