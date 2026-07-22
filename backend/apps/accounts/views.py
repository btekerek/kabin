"""
Auth endpoints: register, login (JWT obtain), refresh, logout (blacklist),
and "me" (current user info for client-side role routing).

Refresh itself is handled by simplejwt's stock TokenRefreshView (wired
directly in urls.py) - ROTATE_REFRESH_TOKENS + BLACKLIST_AFTER_ROTATION
in settings.py already make it rotate and blacklist on every call, so
there's nothing custom to add there.
"""

from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from apps.accounts.emails import generate_verification_code, send_verification_email
from apps.accounts.models import EmailVerificationCode, User
from apps.accounts.serializers import (
    LoginSerializer,
    RegisterSerializer,
    ResendVerificationSerializer,
    UserSerializer,
    VerifyEmailSerializer,
)
from apps.core.exceptions import KabinAPIException


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Atomic so a broken SMTP config can't leave a half-registered,
        # permanently-inactive user squatting on the email with no way
        # to retry (the send happening inside the transaction costs a
        # slightly longer-held DB lock, but that's the right trade here -
        # a failed send must mean nothing was persisted at all).
        with transaction.atomic():
            user = serializer.save()
            code = generate_verification_code()
            EmailVerificationCode.objects.update_or_create(user=user, defaults={"code": code})
            send_verification_email(user, code)

        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


class VerifyEmailView(APIView):
    """Confirms the code emailed at registration and activates the
    account. Issues JWTs directly on success (like LoginView) so the
    client doesn't need a second round-trip through /login/ right after
    verifying - it already proved both the password (at registration)
    and the email (here).
    """

    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "email-verification"

    def post(self, request):
        input_serializer = VerifyEmailSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        data = input_serializer.validated_data

        user = User.objects.filter(email__iexact=data["email"]).first()
        record = EmailVerificationCode.objects.filter(user=user).first() if user else None

        if user is None or record is None or user.is_active:
            raise KabinAPIException(
                code="INVALID_CODE", message="That code is invalid or has expired.", status_code=400
            )

        expiry_cutoff = timezone.now() - timedelta(minutes=settings.EMAIL_VERIFICATION_TTL_MINUTES)
        if record.created_at < expiry_cutoff or record.code != data["code"]:
            raise KabinAPIException(
                code="INVALID_CODE", message="That code is invalid or has expired.", status_code=400
            )

        user.is_active = True
        user.save(update_fields=["is_active"])
        record.delete()

        refresh = RefreshToken.for_user(user)
        return Response({"access": str(refresh.access_token), "refresh": str(refresh)})


class ResendVerificationView(APIView):
    """Silently a no-op for an unknown or already-active email - same
    "don't confirm which emails exist" reasoning as the rest of auth's
    generic INVALID_CREDENTIALS.
    """

    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "email-verification"

    def post(self, request):
        input_serializer = ResendVerificationSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        email = input_serializer.validated_data["email"]

        user = User.objects.filter(email__iexact=email, is_active=False).first()
        if user is not None:
            code = generate_verification_code()
            EmailVerificationCode.objects.update_or_create(user=user, defaults={"code": code})
            send_verification_email(user, code)

        return Response(status=status.HTTP_204_NO_CONTENT)


class LoginView(TokenObtainPairView):
    permission_classes = [permissions.AllowAny]
    serializer_class = LoginSerializer


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


class MeView(generics.RetrieveUpdateAPIView):
    """GET for current-user info; PATCH (username only - id/email are
    read-only on UserSerializer) lets a user change the username they
    were assigned or picked at registration.
    """

    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user
