"""
Session serializers.

Session creation is the one subtle piece: a session and its channels are
created together in a single atomic transaction (see views.py), each
channel getting its own retried-on-collision interpreter_code. The
serializer here only validates input shape; SessionCreateView.create()
owns the actual atomic creation.
"""

from rest_framework import serializers

from apps.sessions.models import Channel, RaiseHandEntry, Session


class ChannelSerializer(serializers.ModelSerializer):
    class Meta:
        model = Channel
        fields = ["id", "language", "interpreter_code", "is_source"]
        read_only_fields = fields


class SessionSerializer(serializers.ModelSerializer):
    channels = ChannelSerializer(many=True, read_only=True)

    class Meta:
        model = Session
        fields = [
            "id",
            "name",
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
    """Shared input shape for both channel join and leave."""

    interpreter_code = serializers.CharField(max_length=20)


class ListenerUuidSerializer(serializers.Serializer):
    """Shared input shape for raise-hand, lower-hand, and speak."""

    listener_uuid = serializers.UUIDField()


class RaiseHandEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = RaiseHandEntry
        fields = ["listener_uuid", "created_at"]
        read_only_fields = fields


class GrantFloorSerializer(serializers.Serializer):
    listener_uuid = serializers.UUIDField()


class SessionCreateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=200)
    source_language = serializers.CharField(max_length=10)
    target_languages = serializers.ListField(
        child=serializers.CharField(max_length=10), allow_empty=False
    )

    def validate_target_languages(self, value):
        normalized = [lang.upper().strip() for lang in value]
        if len(set(normalized)) != len(normalized):
            raise serializers.ValidationError("target_languages must not contain duplicates.")
        return normalized

    def validate_source_language(self, value):
        return value.upper().strip()
