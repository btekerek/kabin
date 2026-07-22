from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from apps.accounts.views import (
    ConfirmPasswordResetView,
    LoginView,
    LogoutView,
    MeView,
    RegisterView,
    RequestPasswordResetView,
    ResendVerificationView,
    VerifyEmailView,
)

urlpatterns = [
    path("register/", RegisterView.as_view(), name="auth-register"),
    path("verify-email/", VerifyEmailView.as_view(), name="auth-verify-email"),
    path("resend-verification/", ResendVerificationView.as_view(), name="auth-resend-verification"),
    path(
        "request-password-reset/",
        RequestPasswordResetView.as_view(),
        name="auth-request-password-reset",
    ),
    path(
        "confirm-password-reset/",
        ConfirmPasswordResetView.as_view(),
        name="auth-confirm-password-reset",
    ),
    path("login/", LoginView.as_view(), name="auth-login"),
    path("refresh/", TokenRefreshView.as_view(), name="auth-refresh"),
    path("logout/", LogoutView.as_view(), name="auth-logout"),
    path("me/", MeView.as_view(), name="auth-me"),
]
