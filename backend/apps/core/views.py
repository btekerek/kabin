"""Infra endpoints: health check for uptime monitors / load balancers."""

from django.db import connections
from django.db.utils import OperationalError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView


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
