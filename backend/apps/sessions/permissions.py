"""Session-scoped permissions."""

from rest_framework.permissions import BasePermission

from apps.accounts.models import User


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
