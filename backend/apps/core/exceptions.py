"""
Custom DRF exception handler.

Every API error the client sees must carry a machine-readable `code` plus
a human-readable `message`, e.g.:

    {"code": "NOT_AUTHORIZED", "message": "You do not have permission..."}

The Flutter client maps `code` to a localized string and only falls back
to `message` (server English) for codes it doesn't recognize. This lets us
add new error cases on the backend without shipping a client update for
every one, while keeping known cases fully localized.

Feature code should raise a KabinAPIException (or a DRF exception that
maps cleanly below) rather than returning ad-hoc error shapes.
"""

from rest_framework.exceptions import APIException
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler

# Maps DRF's default exception classes to our machine-readable codes when
# the raised exception doesn't already specify one. Extend as new
# built-in DRF exceptions show up in practice.
_DEFAULT_CODE_BY_STATUS = {
    400: "MISSING_FIELDS",
    401: "UNAUTHENTICATED",
    403: "NOT_AUTHORIZED",
    404: "NOT_FOUND",
    429: "RATE_LIMITED",
}


class KabinAPIException(APIException):
    """Base class for feature code to raise domain-specific API errors.

    Usage:
        raise KabinAPIException(code="SESSION_FULL", message="...", status_code=403)
    """

    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.status_code = status_code
        super().__init__(detail=message)


def kabin_exception_handler(exc, context):
    response = drf_exception_handler(exc, context)
    if response is None:
        # Unhandled exception -> generic 500, never leak internals.
        return Response(
            {"code": "SERVER_ERROR", "message": "Something went wrong. Please try again."},
            status=500,
        )

    code = getattr(exc, "code", None)
    if not code or not isinstance(code, str):
        code = _DEFAULT_CODE_BY_STATUS.get(response.status_code, "SERVER_ERROR")

    message = getattr(exc, "detail", None)
    message = str(message) if message is not None else "An error occurred."

    response.data = {"code": code, "message": message}
    return response
