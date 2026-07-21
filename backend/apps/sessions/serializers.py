"""
Session serializers.

Session creation is the one subtle piece: a session and its channels are
created together in a single atomic transaction (see views.py), each
channel getting its own retried-on-collision interpreter_code. The
serializer here only validates input shape; SessionCreateView.create()
owns the actual atomic creation.
"""

from rest_framework import serializers

from apps.core.exceptions import KabinAPIException
from apps.core.languages import is_supported_language
from apps.sessions.models import Channel, Message, Session


class ChannelSerializer(serializers.ModelSerializer):
    # Lets the client gate the mic control (only active sessions can be
    # broadcast into) without a second request.
    session_status = serializers.CharField(source="session.status", read_only=True)

    class Meta:
        model = Channel
        # `session` (the owning session's id) is included so
        # ChannelJoinView's response gives an interpreter enough to
        # reach session-scoped endpoints (e.g. chat) - it never learns
        # the session id any other way, since interpreters only ever
        # identify themselves by channel code (see ADR-003).
        fields = ["id", "session", "session_status", "language", "interpreter_code", "is_source"]
        read_only_fields = fields


class SessionSerializer(serializers.ModelSerializer):
    channels = ChannelSerializer(many=True, read_only=True)

    class Meta:
        model = Session
        fields = [
            "id",
            "name",
            "description",
            "source_language",
            "listener_code",
            "status",
            "created_at",
            "channels",
        ]
        read_only_fields = fields


class ListenerChannelSerializer(serializers.ModelSerializer):
    """Channel info safe to show an anonymous listener - no interpreter_code."""

    class Meta:
        model = Channel
        fields = ["id", "language", "is_source"]
        read_only_fields = fields


class SessionLookupSerializer(serializers.ModelSerializer):
    channels = ListenerChannelSerializer(many=True, read_only=True)

    class Meta:
        model = Session
        fields = ["id", "name", "status", "channels"]
        read_only_fields = fields


class SessionLookupInputSerializer(serializers.Serializer):
    listener_code = serializers.CharField(max_length=20)


class SessionJoinSerializer(serializers.Serializer):
    listener_uuid = serializers.UUIDField()
    channel_id = serializers.IntegerField()


class InterpreterCodeSerializer(serializers.Serializer):
    """Shared input shape for both channel join and leave.

    Codes are always generated upper-case (see codes.py), so normalizing
    input here makes lookups case-insensitive without needing an iexact
    query - "en123456" and "EN123456" both resolve to the same channel.
    """

    interpreter_code = serializers.CharField(max_length=20)

    def validate_interpreter_code(self, value):
        return value.strip().upper()


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source="sender.username", read_only=True, default=None)

    class Meta:
        model = Message
        fields = ["id", "channel", "sender_kind", "sender", "sender_name", "body", "created_at"]
        read_only_fields = fields


class MessageCreateSerializer(serializers.Serializer):
    body = serializers.CharField(max_length=2000, allow_blank=False)


class SessionCreateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=200)
    description = serializers.CharField(
        max_length=2000, required=False, allow_blank=True, default=""
    )
    source_language = serializers.CharField(max_length=10)
    target_languages = serializers.ListField(
        child=serializers.CharField(max_length=10), allow_empty=False
    )

    def validate_target_languages(self, value):
        normalized = [lang.upper().strip() for lang in value]
        if len(set(normalized)) != len(normalized):
            raise serializers.ValidationError("target_languages must not contain duplicates.")
        for language in normalized:
            if not is_supported_language(language):
                raise KabinAPIException(
                    code="UNSUPPORTED_LANGUAGE",
                    message=f"'{language}' is not a supported language.",
                    status_code=400,
                )
        return normalized

    def validate_source_language(self, value):
        normalized = value.upper().strip()
        if not is_supported_language(normalized):
            raise KabinAPIException(
                code="UNSUPPORTED_LANGUAGE",
                message=f"'{normalized}' is not a supported language.",
                status_code=400,
            )
        return normalized
