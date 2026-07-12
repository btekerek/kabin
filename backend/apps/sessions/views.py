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

from django.conf import settings
from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.core.exceptions import KabinAPIException
from apps.sessions.agora import build_listener_token
from apps.sessions.codes import generate_interpreter_code, generate_listener_code
from apps.sessions.models import Channel, ListenerSession, Session
from apps.sessions.permissions import IsGuide, IsSessionOwner
from apps.sessions.serializers import (
    ListenerChannelSerializer,
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
        return Response(SessionSerializer(session).data)


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

        token = build_listener_token(channel.agora_channel_name, str(listener_uuid))
        return Response(
            {
                "agora_app_id": settings.AGORA_APP_ID,
                "agora_channel_name": channel.agora_channel_name,
                "agora_token": token,
                "expires_in": settings.AGORA_TOKEN_TTL_SECONDS,
                "channel": ListenerChannelSerializer(channel).data,
            }
        )


class SessionStartView(_SessionTransitionView):
    target_status = Session.Status.ACTIVE


class SessionStopView(_SessionTransitionView):
    # Stop pauses the event: not_started status, and (once the Q&A slice
    # exists) clears the raise-hand queue and any granted floor. No queue
    # model exists yet, so there's nothing to clear here today.
    target_status = Session.Status.NOT_STARTED


class SessionEndView(_SessionTransitionView):
    target_status = Session.Status.ENDED
