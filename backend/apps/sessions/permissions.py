"""Session-scoped permissions."""

import uuid as uuid_lib

from rest_framework.permissions import BasePermission

from apps.accounts.models import User
from apps.sessions.models import ChannelInterpreter, ListenerSession


class IsGuide(BasePermission):
    """Only Guide accounts may create/manage sessions."""

    def has_permission(self, request, view):
        return bool(
            request.user and request.user.is_authenticated and request.user.role == User.Role.GUIDE
        )


class IsSessionOwner(BasePermission):
    """Object-level check: only the owning Guide may act on a session."""

    def has_object_permission(self, request, view, obj):
        return obj.owner_id == request.user.id


class IsInterpreter(BasePermission):
    """Only Interpreter accounts may claim/release channels."""

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.role == User.Role.INTERPRETER
        )


class IsSessionParticipant(BasePermission):
    """Object-level: true if the caller is actually part of this session.

    Covers all three sender kinds from ADR-005 with one check: the
    owning guide, an interpreter currently holding a claim on one of the
    session's channels, or a listener with a ListenerSession row. For
    listeners there's no auth token to check, so their identity comes
    from `listener_uuid` in the request body (POST) or query params
    (GET) instead - same anonymous-identity model as the rest of the
    listener-facing endpoints.
    """

    def has_object_permission(self, request, view, session):
        user = request.user
        if user and user.is_authenticated:
            if user.role == User.Role.GUIDE:
                return session.owner_id == user.id
            if user.role == User.Role.INTERPRETER:
                return ChannelInterpreter.objects.filter(
                    channel__session=session, interpreter=user
                ).exists()
            return False

        raw_listener_uuid = request.data.get("listener_uuid") or request.query_params.get(
            "listener_uuid"
        )
        if not raw_listener_uuid:
            return False
        try:
            listener_uuid = uuid_lib.UUID(str(raw_listener_uuid))
        except (ValueError, AttributeError, TypeError):
            return False
        return ListenerSession.objects.filter(session=session, listener_uuid=listener_uuid).exists()
