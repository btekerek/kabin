"""Session-scoped permissions.

There is no fixed account role (see apps.accounts.models.User) - "guide"
and "interpreter" are per-session relationships derived from who owns a
Session or holds a ChannelInterpreter claim, not a property checked on
the account itself. Any authenticated user can create a session
(IsSessionOwner then gates further action on it to whoever owns it) and/
or claim any open channel (no permission class needed beyond
IsAuthenticated - ChannelJoinView's own claim logic in views.py handles
the "already someone else's" conflict).
"""

import uuid as uuid_lib

from rest_framework.permissions import BasePermission

from apps.sessions.models import ChannelInterpreter, ListenerSession


class IsSessionOwner(BasePermission):
    """Object-level check: only the owning user may act on a session."""

    def has_object_permission(self, request, view, obj):
        return obj.owner_id == request.user.id


class IsSessionParticipant(BasePermission):
    """Object-level: true if the caller is actually part of this session.

    Covers all three sender kinds from ADR-005 with one check: the
    owning user (guide, by virtue of ownership), a user currently
    holding a claim on one of the session's channels (interpreter, by
    virtue of the claim), or a listener with a ListenerSession row. For
    listeners there's no auth token to check, so their identity comes
    from `listener_uuid` in the request body (POST) or query params
    (GET) instead - same anonymous-identity model as the rest of the
    listener-facing endpoints.
    """

    def has_object_permission(self, request, view, session):
        user = request.user
        if user and user.is_authenticated:
            if session.owner_id == user.id:
                return True
            return ChannelInterpreter.objects.filter(
                channel__session=session, interpreter=user
            ).exists()

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
