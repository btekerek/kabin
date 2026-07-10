"""
Root URL configuration.

Only infra endpoints (health check, OpenAPI schema/docs) are wired up at
scaffold time. Feature endpoints (auth, sessions, etc.) are added as each
vertical slice is built.
"""

from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
)

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/health/", include("apps.core.urls")),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
    # path("api/auth/", include("apps.accounts.urls")),  # next slice
    # path("api/sessions/", include("apps.sessions.urls")),  # next slice
]
