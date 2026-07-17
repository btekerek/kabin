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
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.accounts.models import User
from apps.core.exceptions import KabinAPIException
from apps.sessions.agora import build_floor_token, build_interpreter_token, build_listener_token
from apps.sessions.codes import generate_interpreter_code, generate_listener_code
from apps.sessions.models import (
    Channel,
    ChannelInterpreter,
    ListenerSession,
    Message,
    RaiseHandEntry,
    Session,
)
from apps.sessions.permissions import IsGuide, IsInterpreter, IsSessionOwner, IsSessionParticipant
from apps.sessions.serializers import (
    ChannelSerializer,
    GrantFloorSerializer,
    InterpreterCodeSerializer,
    ListenerChannelSerializer,
    ListenerUuidSerializer,
    MessageCreateSerializer,
    MessageSerializer,
    RaiseHandEntrySerializer,
    SessionCreateSerializer,
    SessionJoinSerializer,
    SessionLookupInputSerializer,
    SessionLookupSerializer,
    SessionSerializer,
)


class SessionListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsGuide]
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
                source_language=data["source_language"],
                listener_code=generate_listener_code(),
            )
            Channel.objects.create(
                session=session,
                language=data["source_language"],
                interpreter_code=generate_interpreter_code(data["source_language"]),
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
    permission_classes = [permissions.IsAuthenticated, IsGuide, IsSessionOwner]
    queryset = Session.objects.all()
    serializer_class = SessionSerializer


class _SessionTransitionView(APIView):
    """Shared logic for start/stop/end - subclasses just set target_status."""

    permission_classes = [permissions.IsAuthenticated, IsGuide, IsSessionOwner]
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
        """Hook for subclasses with side effects beyond the status change."""


class SessionLookupView(APIView):
    """Public: PIN -> session name/status + channel list.

    No auth - listeners aren't Django users. Join codes are short and
    guessable by design (see codes.py), so this is the one endpoint that
    risk is real for; it's rate-limited via the "session-lookup" throttle
    scope (see ADR-002).
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
    spending a second seat against the listener cap - see ADR-002.
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


class ChannelJoinView(APIView):
    """Authenticated (Interpreter role): code -> claim channel + publisher token.

    Claim semantics (see ADR-003): free -> claim it; already yours ->
    refresh (reconnect case); someone else's -> CHANNEL_ALREADY_STAFFED.
    """

    permission_classes = [permissions.IsAuthenticated, IsInterpreter]

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
            claim, created = ChannelInterpreter.objects.select_for_update().get_or_create(
                channel=channel, defaults={"interpreter": request.user}
            )
            if not created and claim.interpreter_id != request.user.id:
                raise KabinAPIException(
                    code="CHANNEL_ALREADY_STAFFED",
                    message="Another interpreter is already broadcasting on this channel.",
                    status_code=409,
                )

        token = build_interpreter_token(channel.agora_channel_name)
        return Response(
            {
                "agora_app_id": settings.AGORA_APP_ID,
                "agora_channel_name": channel.agora_channel_name,
                "agora_token": token,
                "expires_in": settings.AGORA_TOKEN_TTL_SECONDS,
                "channel": ChannelSerializer(channel).data,
            }
        )


class ChannelLeaveView(APIView):
    """Authenticated (Interpreter role): release the caller's own claim.

    A no-op if the caller doesn't currently hold the channel - safe to
    call defensively without checking state first.
    """

    permission_classes = [permissions.IsAuthenticated, IsInterpreter]

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
    """Stop pauses the event: not_started status, and clears the Q&A
    queue and any granted floor (see ADR-004) - a fresh Q&A period
    starts clean the next time the guide enters qa_mode."""

    target_status = Session.Status.NOT_STARTED

    def after_transition(self, session):
        RaiseHandEntry.objects.filter(session=session).delete()
        if session.approved_listener_uuid is not None:
            session.approved_listener_uuid = None
            session.save(update_fields=["approved_listener_uuid"])


class SessionEndView(_SessionTransitionView):
    target_status = Session.Status.ENDED


class SessionQaModeView(_SessionTransitionView):
    target_status = Session.Status.QA_MODE


class RaiseHandView(APIView):
    """Public: listener joins the Q&A queue.

    Requires the session to be in qa_mode and the caller to already be a
    ListenerSession member (see ADR-004) - you can't ask a question in a
    room you haven't joined. Idempotent: raising an already-raised hand
    just returns the same queue position.
    """

    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        session = get_object_or_404(Session, pk=pk)

        if session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended.",
                status_code=400,
            )
        if session.status != Session.Status.QA_MODE:
            raise KabinAPIException(
                code="NOT_IN_QA_MODE",
                message="You can only raise your hand during Q&A.",
                status_code=400,
            )

        input_serializer = ListenerUuidSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        listener_uuid = input_serializer.validated_data["listener_uuid"]

        if not ListenerSession.objects.filter(
            session=session, listener_uuid=listener_uuid
        ).exists():
            raise KabinAPIException(
                code="NOT_JOINED",
                message="Join the session before raising your hand.",
                status_code=403,
            )

        entry, _created = RaiseHandEntry.objects.get_or_create(
            session=session, listener_uuid=listener_uuid
        )
        ordered_ids = list(
            RaiseHandEntry.objects.filter(session=session).values_list("id", flat=True)
        )
        return Response({"position": ordered_ids.index(entry.id) + 1})


class LowerHandView(APIView):
    """Public: listener leaves the Q&A queue - a no-op if not queued."""

    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        session = get_object_or_404(Session, pk=pk)

        input_serializer = ListenerUuidSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)

        RaiseHandEntry.objects.filter(
            session=session, listener_uuid=input_serializer.validated_data["listener_uuid"]
        ).delete()

        return Response(status=status.HTTP_204_NO_CONTENT)


class SpeakView(APIView):
    """Public: listener holding the floor gets a publisher token into the
    source channel (see ADR-004) - not whatever channel they were
    listening to, since the question needs to reach the room and every
    interpreter."""

    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        session = get_object_or_404(Session, pk=pk)

        if session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended.",
                status_code=400,
            )

        input_serializer = ListenerUuidSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        listener_uuid = input_serializer.validated_data["listener_uuid"]

        if session.approved_listener_uuid != listener_uuid:
            raise KabinAPIException(
                code="NOT_YOUR_TURN",
                message="You have not been granted the floor.",
                status_code=403,
            )

        source_channel = get_object_or_404(Channel, session=session, is_source=True)
        token = build_floor_token(source_channel.agora_channel_name)
        return Response(
            {
                "agora_app_id": settings.AGORA_APP_ID,
                "agora_channel_name": source_channel.agora_channel_name,
                "agora_token": token,
                "expires_in": settings.AGORA_TOKEN_TTL_SECONDS,
                "channel": ListenerChannelSerializer(source_channel).data,
            }
        )


class SessionQueueView(APIView):
    """Authenticated (session owner): who's currently waiting, in order."""

    permission_classes = [permissions.IsAuthenticated, IsGuide, IsSessionOwner]

    def get(self, request, pk):
        session = get_object_or_404(Session, pk=pk)
        self.check_object_permissions(request, session)

        entries = RaiseHandEntry.objects.filter(session=session)
        return Response(RaiseHandEntrySerializer(entries, many=True).data)


class GrantFloorView(APIView):
    """Authenticated (session owner): grant the floor to a queued listener.

    Implicitly replaces whoever held the floor before - see ADR-004 for
    why that's fine here but not in the interpreter channel-claim flow.
    """

    permission_classes = [permissions.IsAuthenticated, IsGuide, IsSessionOwner]

    def post(self, request, pk):
        session = get_object_or_404(Session, pk=pk)
        self.check_object_permissions(request, session)

        if session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended.",
                status_code=400,
            )

        input_serializer = GrantFloorSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        listener_uuid = input_serializer.validated_data["listener_uuid"]

        if not RaiseHandEntry.objects.filter(session=session, listener_uuid=listener_uuid).exists():
            raise KabinAPIException(
                code="NOT_IN_QUEUE",
                message="That listener has not raised their hand.",
                status_code=400,
            )

        with transaction.atomic():
            RaiseHandEntry.objects.filter(session=session, listener_uuid=listener_uuid).delete()
            session.approved_listener_uuid = listener_uuid
            session.save(update_fields=["approved_listener_uuid"])

        return Response(SessionSerializer(session).data)


class RevokeFloorView(APIView):
    """Authenticated (session owner): clear the floor, if any is granted."""

    permission_classes = [permissions.IsAuthenticated, IsGuide, IsSessionOwner]

    def post(self, request, pk):
        session = get_object_or_404(Session, pk=pk)
        self.check_object_permissions(request, session)

        if session.approved_listener_uuid is not None:
            session.approved_listener_uuid = None
            session.save(update_fields=["approved_listener_uuid"])

        return Response(SessionSerializer(session).data)


class MessageListCreateView(APIView):
    """Chat: anyone actually in the session (see IsSessionParticipant) can
    read history and send. REST is the only write path - sending a
    message here also pushes it to the "session-<id>-chat" channel-layer
    group so connected WebSocket clients receive it immediately. See
    ADR-005 for why the socket itself never accepts client-sent messages.

    permission_classes is AllowAny, not [IsSessionParticipant], and the
    participant check is called directly below instead of through
    check_object_permissions. Reason: DRF's permission_denied() turns a
    failed object permission into 401 (not 403) whenever no authenticator
    succeeded - which is every anonymous listener request, since none of
    them present a JWT. Every other listener-facing endpoint in this app
    sidesteps that DRF quirk by using AllowAny + an explicit
    KabinAPIException; this one reuses the same IsSessionParticipant
    logic as a plain function call so the 403 stays a real 403.
    """

    permission_classes = [permissions.AllowAny]

    def _get_session(self, request, pk):
        session = get_object_or_404(Session, pk=pk)
        if not IsSessionParticipant().has_object_permission(request, self, session):
            raise KabinAPIException(
                code="NOT_A_PARTICIPANT",
                message="You are not part of this session.",
                status_code=403,
            )
        return session

    def get(self, request, pk):
        session = self._get_session(request, pk)
        messages = Message.objects.filter(session=session)
        return Response(MessageSerializer(messages, many=True).data)

    def post(self, request, pk):
        session = self._get_session(request, pk)

        if session.status == Session.Status.ENDED:
            raise KabinAPIException(
                code="SESSION_ENDED",
                message="This session has ended.",
                status_code=400,
            )

        input_serializer = MessageCreateSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        body = input_serializer.validated_data["body"]

        user = request.user
        if user and user.is_authenticated:
            sender_kind = (
                Message.SenderKind.GUIDE
                if user.role == User.Role.GUIDE
                else Message.SenderKind.INTERPRETER
            )
            message = Message.objects.create(
                session=session, sender_kind=sender_kind, sender=user, body=body
            )
        else:
            message = Message.objects.create(
                session=session,
                sender_kind=Message.SenderKind.LISTENER,
                sender_listener_uuid=input_serializer.validated_data["listener_uuid"],
                body=body,
            )

        payload = MessageSerializer(message).data
        async_to_sync(get_channel_layer().group_send)(
            f"session-{session.id}-chat",
            {"type": "chat.message", "message": payload},
        )

        return Response(payload, status=status.HTTP_201_CREATED)
