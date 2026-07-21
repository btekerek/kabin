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

from rest_framework.permissions import BasePermission

from apps.sessions.models import ChannelInterpreter


class IsSessionOwner(BasePermission):
    """Object-level check: only the owning user may act on a session."""

    def has_object_permission(self, request, view, obj):
        return obj.owner_id == request.user.id


class IsSessionStaff(BasePermission):
    """Object-level: true if the caller is the session's owning guide or
    holds an interpreter claim on any of its channels. Listeners are
    never session staff - they have no chat access at all (see
    Message model).
    """

    def has_object_permission(self, request, view, session):
        user = request.user
        if not (user and user.is_authenticated):
            return False
        if session.owner_id == user.id:
            return True
        return ChannelInterpreter.objects.filter(
            channel__session=session, interpreter=user
        ).exists()


class IsChannelInterpreter(BasePermission):
    """Object-level: true if the caller holds an interpreter claim on
    this specific channel. Used to scope per-channel chat to only the
    interpreter(s) sharing that channel - not the guide, not
    interpreters on other channels.
    """

    def has_object_permission(self, request, view, channel):
        user = request.user
        if not (user and user.is_authenticated):
            return False
        return ChannelInterpreter.objects.filter(channel=channel, interpreter=user).exists()
