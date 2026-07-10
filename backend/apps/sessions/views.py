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

from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.exceptions import KabinAPIException
from apps.sessions.codes import generate_interpreter_code, generate_listener_code
from apps.sessions.models import Channel, Session
from apps.sessions.permissions import IsGuide, IsSessionOwner
from apps.sessions.serializers import SessionCreateSerializer, SessionSerializer


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


class SessionStartView(_SessionTransitionView):
    target_status = Session.Status.ACTIVE


class SessionStopView(_SessionTransitionView):
    # Stop pauses the event: not_started status, and (once the Q&A slice
    # exists) clears the raise-hand queue and any granted floor. No queue
    # model exists yet, so there's nothing to clear here today.
    target_status = Session.Status.NOT_STARTED


class SessionEndView(_SessionTransitionView):
    target_status = Session.Status.ENDED
