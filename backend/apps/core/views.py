"""Infra endpoints: health check for uptime monitors / load balancers,
plus the public language registry."""

from django.db import connections
from django.db.utils import OperationalError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.languages import language_list


class HealthCheckView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        db_ok = True
        try:
            connections["default"].cursor()
        except OperationalError:
            db_ok = False

        status_code = 200 if db_ok else 503
        return Response({"status": "ok" if db_ok else "degraded", "db": db_ok}, status=status_code)


class LanguageListView(APIView):
    """Public: the full supported-language registry, [{code, name}].

    No auth, no throttle - this is static reference data (not a
    guessable-secret lookup like session-lookup), meant for clients to
    build a language picker from the same source of truth the backend
    validates session creation against.
    """

    permission_classes = [AllowAny]

    def get(self, request):
        return Response(language_list())
