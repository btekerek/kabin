"""
Session CRUD + lifecycle endpoints.

Creation is atomic: a session and every one of its channels (source +
each target language) are created in a single transaction, each getting
an independently retried-on-collision join code (see codes.py). If any
channel fails to get a code, the whole session creation rolls back rather
than leaving a partially-created session behind.

Lifecycle actions (start/stop/end) go through Session.can_transition_to
rather than a free-form status field, so "ended" can never be walked back
out of - see models.py for the allowed-transitions table.
"""

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.core.exceptions import KabinAPIException
from apps.sessions.agora import (
    build_guide_broadcast_token,
    build_interpreter_token,
    build_listener_token,
)
from apps.sessions.codes import generate_interpreter_code, generate_listener_code
from apps.sessions.models import (
    Channel,
    ChannelInterpreter,
    ListenerSession,
    Message,
    Session,
)
from apps.sessions.permissions import IsChannelInterpreter, IsSessionOwner, IsSessionStaff
from apps.sessions.serializers import (
    ChannelSerializer,
    InterpreterCodeSerializer,
    ListenerChannelSerializer,
    MessageCreateSerializer,
    MessageSerializer,
    SessionCreateSerializer,
    SessionJoinSerializer,
    SessionLookupInputSerializer,
    SessionLookupSerializer,
    SessionSerializer,
)


class SessionListCreateView(generics.ListCreateAPIView):
    """Any authenticated user may create a session - doing so makes them
    that session's owner (its "guide"), a per-session relationship, not
    an account-wide role. See permissions.py module docstring.
    """

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = SessionSerializer

    def get_queryset(self):
        return Session.objects.filter(owner=self.request.user)

    def create(self, request, *args, **kwargs):
        input_serializer = SessionCreateSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        data = input_serializer.validated_data

        with transaction.atomic():
            session = Session.objects.create(
                owner=request.user,
                name=data["name"],
                description=data["description"],
                source_language=data["source_language"],
                listener_code=generate_listener_code(),
            )
            Channel.objects.create(
                session=session,
                language=data["source_language"],
                is_source=True,
            )
            for language in data["target_languages"]:
                Channel.objects.create(
                    session=session,
                    language=language,
                    interpreter_code=generate_interpreter_code(language),
                    is_source=False,
                )

        return Response(SessionSerializer(session).data, status=status.HTTP_201_CREATED)


class SessionDetailView(generics.RetrieveAPIView):
    permission_classes = [permissions.IsAuthenticated, IsSessionOwner]
    queryset = Session.objects.all()
    serializer_class = SessionSerializer


class _SessionTransitionView(APIView):
    """Shared logic for start/stop/end - subclasses just set target_status."""

    permission_classes = [permissions.IsAuthenticated, IsSessionOwner]
    target_status = None

    def get_object(self, pk):
        session = get_object_or_404(Session, pk=pk)
        self.check_object_permissions(self.request, session)
        return session

    def post(self, request, pk):
        session = self.get_object(pk)

        if session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended and cannot be changed.",
                status_code=400,
            )

        if not session.can_transition_to(self.target_status):
            raise KabinAPIException(
                code="INVALID_TRANSITION",
                message=f"Cannot go from '{session.status}' to '{self.target_status}'.",
                status_code=400,
            )

        session.status = self.target_status
        session.save(update_fields=["status"])
        self.after_transition(session)
        return Response(SessionSerializer(session).data)

    def after_transition(self, session):
        """Pushes the new status to every channel's mic-presence group
        instantly - interpreters may have joined a channel before the
        guide started the session, and BroadcastingScreen's mic gate
        (only broadcast while active) needs to unlock the moment it
        does, not on the next poll.
        """
        channel_layer = get_channel_layer()
        for channel_id in session.channels.values_list("id", flat=True):
            async_to_sync(channel_layer.group_send)(
                f"channel-{channel_id}-mic",
                {"type": "session_status", "status": session.status},
            )


class SessionBroadcastView(APIView):
    """Authenticated (Guide/session-owner): publisher token for the
    session's own source channel.

    This is what makes the Guide's live mic actually reach anyone else -
    interpreters listening for material to translate, and any listener
    who picks "original audio" instead of a translated channel. Mic
    on/off is deliberately independent of session status (start/stop/
    end) - the Guide can test their mic or go live at any point before
    the session ends, not only while status is active.
    """

    permission_classes = [permissions.IsAuthenticated, IsSessionOwner]

    def post(self, request, pk):
        session = get_object_or_404(Session, pk=pk)
        self.check_object_permissions(request, session)

        if session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended and cannot be broadcast to.",
                status_code=400,
            )

        source_channel = get_object_or_404(Channel, session=session, is_source=True)
        token = build_guide_broadcast_token(source_channel.agora_channel_name)
        return Response(
            {
                "agora_app_id": settings.AGORA_APP_ID,
                "agora_channel_name": source_channel.agora_channel_name,
                "agora_token": token,
                "expires_in": settings.AGORA_TOKEN_TTL_SECONDS,
                "channel": ChannelSerializer(source_channel).data,
            }
        )


class SessionLookupView(APIView):
    """Public: PIN -> session name/status + channel list.

    No auth - listeners aren't Django users. Join codes are short and
    guessable by design (see codes.py), so this is the one endpoint that
    risk is real for; it's rate-limited via the "session-lookup" throttle
    scope.
    """

    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "session-lookup"

    def post(self, request):
        input_serializer = SessionLookupInputSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)

        try:
            session = Session.objects.get(
                listener_code=input_serializer.validated_data["listener_code"]
            )
        except Session.DoesNotExist:
            raise KabinAPIException(
                code="SESSION_NOT_FOUND",
                message="No session matches that code.",
                status_code=404,
            ) from None

        return Response(SessionLookupSerializer(session).data)


class SessionJoinView(APIView):
    """Public: listener picks a channel, gets back an Agora audience token.

    Rejoining with the same listener_uuid switches channel instead of
    spending a second seat against the listener cap.
    """

    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        session = get_object_or_404(Session, pk=pk)

        if session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended and cannot be joined.",
                status_code=400,
            )

        input_serializer = SessionJoinSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        listener_uuid = input_serializer.validated_data["listener_uuid"]
        channel = get_object_or_404(
            Channel, pk=input_serializer.validated_data["channel_id"], session=session
        )

        with transaction.atomic():
            # Lock the session row so concurrent joins against the same
            # session serialize around the capacity check below.
            Session.objects.select_for_update().get(pk=session.pk)

            existing = (
                ListenerSession.objects.select_for_update()
                .filter(session=session, listener_uuid=listener_uuid)
                .first()
            )
            if existing is None:
                current_count = ListenerSession.objects.filter(session=session).count()
                if current_count >= settings.SESSION_LISTENER_CAP_DEFAULT:
                    raise KabinAPIException(
                        code="LISTENER_CAP_REACHED",
                        message="This session is at capacity.",
                        status_code=403,
                    )
                ListenerSession.objects.create(
                    session=session, listener_uuid=listener_uuid, channel=channel
                )
            elif existing.channel_id != channel.id:
                existing.channel = channel
                existing.save(update_fields=["channel"])

        token = build_listener_token(channel.agora_channel_name)
        return Response(
            {
                "agora_app_id": settings.AGORA_APP_ID,
                "agora_channel_name": channel.agora_channel_name,
                "agora_token": token,
                "expires_in": settings.AGORA_TOKEN_TTL_SECONDS,
                "channel": ListenerChannelSerializer(channel).data,
            }
        )


def _relay_payload(relay_channel):
    return {
        "agora_app_id": settings.AGORA_APP_ID,
        "agora_channel_name": relay_channel.agora_channel_name,
        "agora_token": build_listener_token(relay_channel.agora_channel_name),
        "expires_in": settings.AGORA_TOKEN_TTL_SECONDS,
        "channel": ListenerChannelSerializer(relay_channel).data,
    }


def _default_relay(channel):
    if channel.is_source:
        return None
    source_channel = Channel.objects.get(session=channel.session, is_source=True)
    return _relay_payload(source_channel)


def _available_relay_channels(channel):
    if channel.is_source:
        return []
    others = Channel.objects.filter(session=channel.session).exclude(pk=channel.pk)
    return ListenerChannelSerializer(others, many=True).data


def _available_target_channels(session):
    targets = Channel.objects.filter(session=session, is_source=False)
    return ListenerChannelSerializer(targets, many=True).data


def _claim_payload(channel):
    """Shared response shape for ChannelJoinView and ChannelSwitchView -
    publish credentials for [channel] plus everything the interpreter's
    two dropdowns (target language, relay/source language) need to
    render themselves.
    """
    token = build_interpreter_token(channel.agora_channel_name)
    return {
        "agora_app_id": settings.AGORA_APP_ID,
        "agora_channel_name": channel.agora_channel_name,
        "agora_token": token,
        "expires_in": settings.AGORA_TOKEN_TTL_SECONDS,
        "channel": ChannelSerializer(channel).data,
        "relay": _default_relay(channel),
        "available_relay_channels": _available_relay_channels(channel),
        "available_target_channels": _available_target_channels(channel.session),
    }


class ChannelJoinView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        input_serializer = InterpreterCodeSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)

        try:
            channel = Channel.objects.select_related("session").get(
                interpreter_code=input_serializer.validated_data["interpreter_code"]
            )
        except Channel.DoesNotExist:
            raise KabinAPIException(
                code="CHANNEL_NOT_FOUND",
                message="No channel matches that code.",
                status_code=404,
            ) from None

        if channel.session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended and cannot be joined.",
                status_code=400,
            )

        with transaction.atomic():
            ChannelInterpreter.objects.select_for_update().get_or_create(
                channel=channel, interpreter=request.user
            )

        return Response(_claim_payload(channel))


class ChannelRelayView(APIView):
    """Lets an interpreter switch which channel they're relaying from
    (listening to while they interpret) at any time - not just the
    session's original source. Supports pivot setups where one
    interpreter relays from another channel's translation instead of
    the original audio.
    """

    permission_classes = [permissions.IsAuthenticated, IsChannelInterpreter]

    def post(self, request, pk):
        channel = get_object_or_404(Channel, pk=pk)
        self.check_object_permissions(request, channel)

        relay_channel = get_object_or_404(
            Channel, pk=request.data.get("relay_channel_id"), session=channel.session
        )
        if relay_channel.id == channel.id:
            raise KabinAPIException(
                code="INVALID_RELAY_CHANNEL",
                message="Can't relay from your own channel.",
                status_code=400,
            )

        return Response(_relay_payload(relay_channel))


class ChannelSwitchView(APIView):
    """Lets an interpreter move their own claim to a different (target,
    non-source) channel in the same session, without leaving/rejoining
    by code - e.g. picking a different language to translate into.
    Multiple interpreters may already share one channel (see
    ChannelInterpreter), so this never has to resolve a staffing
    conflict - it's just "drop my claim here, pick it up there."
    """

    permission_classes = [permissions.IsAuthenticated, IsChannelInterpreter]

    def post(self, request, pk):
        channel = get_object_or_404(Channel, pk=pk)
        self.check_object_permissions(request, channel)

        if channel.session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended.",
                status_code=400,
            )

        target_channel = get_object_or_404(
            Channel,
            pk=request.data.get("target_channel_id"),
            session=channel.session,
            is_source=False,
        )
        if target_channel.id == channel.id:
            raise KabinAPIException(
                code="INVALID_TARGET_CHANNEL",
                message="Already on that channel.",
                status_code=400,
            )

        with transaction.atomic():
            ChannelInterpreter.objects.filter(channel=channel, interpreter=request.user).delete()
            ChannelInterpreter.objects.select_for_update().get_or_create(
                channel=target_channel, interpreter=request.user
            )

        return Response(_claim_payload(target_channel))


class ChannelLeaveView(APIView):
    """Authenticated (Interpreter role): release the caller's own claim.

    A no-op if the caller doesn't currently hold the channel - safe to
    call defensively without checking state first.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        input_serializer = InterpreterCodeSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)

        ChannelInterpreter.objects.filter(
            channel__interpreter_code=input_serializer.validated_data["interpreter_code"],
            interpreter=request.user,
        ).delete()

        return Response(status=status.HTTP_204_NO_CONTENT)


class SessionStartView(_SessionTransitionView):
    target_status = Session.Status.ACTIVE


class SessionStopView(_SessionTransitionView):
    target_status = Session.Status.NOT_STARTED


class SessionEndView(_SessionTransitionView):
    target_status = Session.Status.ENDED


class _BaseMessageView(APIView):
    """Shared history pagination for both chat scopes below - see
    MessageListCreateView (general) and ChannelMessageListCreateView
    (per-channel).
    """

    permission_classes = [permissions.IsAuthenticated]

    DEFAULT_PAGE_SIZE = 50
    MAX_PAGE_SIZE = 200

    def _paginated(self, request, queryset):
        """Returns the most recent `limit` messages (default/max: 50/200),
        chronological ascending. Pass `before_id` (a message id already
        seen) to page further back in time - the response is the `limit`
        messages immediately before that one, still chronological
        ascending.

        Without `before_id` this is "the tail of the conversation," not
        an offset - so it stays correct even if new messages arrive
        between page requests, unlike a page-number scheme would.
        """
        limit = self._parse_limit(request.query_params.get("limit"))

        before_id = request.query_params.get("before_id")
        if before_id is not None:
            cursor = get_object_or_404(queryset, pk=before_id)
            queryset = queryset.filter(
                Q(created_at__lt=cursor.created_at)
                | Q(created_at=cursor.created_at, id__lt=cursor.id)
            )

        page = list(queryset.order_by("-created_at", "-id")[:limit])
        page.reverse()
        return Response(MessageSerializer(page, many=True).data)

    def _parse_limit(self, raw_limit):
        try:
            limit = int(raw_limit)
        except (TypeError, ValueError):
            return self.DEFAULT_PAGE_SIZE
        return max(1, min(limit, self.MAX_PAGE_SIZE))


class MessageListCreateView(_BaseMessageView):
    """General chat: guide + every interpreter in the session (see
    IsSessionStaff) - listeners never have chat access. REST is the only
    write path - sending a message here also pushes it to the
    "session-<id>-chat" channel-layer group so connected WebSocket
    clients receive it immediately.
    """

    permission_classes = [permissions.IsAuthenticated, IsSessionStaff]

    def _get_session(self, pk):
        session = get_object_or_404(Session, pk=pk)
        self.check_object_permissions(self.request, session)
        return session

    def get(self, request, pk):
        session = self._get_session(pk)
        return self._paginated(
            request, Message.objects.filter(session=session, channel__isnull=True)
        )

    def post(self, request, pk):
        session = self._get_session(pk)

        if session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended.",
                status_code=400,
            )

        input_serializer = MessageCreateSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)

        sender_kind = (
            Message.SenderKind.GUIDE
            if session.owner_id == request.user.id
            else Message.SenderKind.INTERPRETER
        )
        message = Message.objects.create(
            session=session,
            sender_kind=sender_kind,
            sender=request.user,
            body=input_serializer.validated_data["body"],
        )

        payload = MessageSerializer(message).data
        async_to_sync(get_channel_layer().group_send)(
            f"session-{session.id}-chat",
            {"type": "chat.message", "message": payload},
        )

        return Response(payload, status=status.HTTP_201_CREATED)


class ChannelMessageListCreateView(_BaseMessageView):
    """Per-channel chat: only the interpreter(s) holding a claim on this
    channel (see IsChannelInterpreter) - not the guide, not interpreters
    on other channels. Lets interpreters sharing a channel coordinate
    privately alongside the session-wide general chat.
    """

    permission_classes = [permissions.IsAuthenticated, IsChannelInterpreter]

    def _get_channel(self, pk):
        channel = get_object_or_404(Channel, pk=pk)
        self.check_object_permissions(self.request, channel)
        return channel

    def get(self, request, pk):
        channel = self._get_channel(pk)
        return self._paginated(request, Message.objects.filter(channel=channel))

    def post(self, request, pk):
        channel = self._get_channel(pk)

        if channel.session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended.",
                status_code=400,
            )

        input_serializer = MessageCreateSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)

        message = Message.objects.create(
            session=channel.session,
            channel=channel,
            sender_kind=Message.SenderKind.INTERPRETER,
            sender=request.user,
            body=input_serializer.validated_data["body"],
        )

        payload = MessageSerializer(message).data
        async_to_sync(get_channel_layer().group_send)(
            f"channel-{channel.id}-chat",
            {"type": "chat.message", "message": payload},
        )

        return Response(payload, status=status.HTTP_201_CREATED)
