"""
Auth endpoints: register, login (JWT obtain), refresh, logout (blacklist),
and "me" (current user info for client-side role routing).

Refresh itself is handled by simplejwt's stock TokenRefreshView (wired
directly in urls.py) - ROTATE_REFRESH_TOKENS + BLACKLIST_AFTER_ROTATION
in settings.py already make it rotate and blacklist on every call, so
there's nothing custom to add there.
"""

from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from apps.accounts.models import User
from apps.accounts.serializers import (
    EmailTokenObtainPairSerializer,
    RegisterSerializer,
    UserSerializer,
)
from apps.core.exceptions import KabinAPIException


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


class LoginView(TokenObtainPairView):
    permission_classes = [permissions.AllowAny]
    serializer_class = EmailTokenObtainPairSerializer


class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get("refresh")
        if not refresh_token:
            raise KabinAPIException(
                code="MISSING_FIELDS",
                message="The 'refresh' field is required.",
                status_code=400,
            )
        try:
            RefreshToken(refresh_token).blacklist()
        except TokenError:
            # Already invalid/expired/blacklisted - logout is still a
            # success from the client's point of view either way.
            pass
        return Response(status=status.HTTP_205_RESET_CONTENT)


class MeView(generics.RetrieveAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user
