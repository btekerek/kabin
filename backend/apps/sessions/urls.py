from django.urls import path

from apps.sessions.views import (
    SessionDetailView,
    SessionEndView,
    SessionJoinView,
    SessionListCreateView,
    SessionLookupView,
    SessionStartView,
    SessionStopView,
)

urlpatterns = [
    path("", SessionListCreateView.as_view(), name="session-list-create"),
    path("lookup/", SessionLookupView.as_view(), name="session-lookup"),
    path("<int:pk>/", SessionDetailView.as_view(), name="session-detail"),
    path("<int:pk>/start/", SessionStartView.as_view(), name="session-start"),
    path("<int:pk>/stop/", SessionStopView.as_view(), name="session-stop"),
    path("<int:pk>/end/", SessionEndView.as_view(), name="session-end"),
    path("<int:pk>/join/", SessionJoinView.as_view(), name="session-join"),
]
