from django.urls import path

from apps.sessions.views import (
    GrantFloorView,
    LowerHandView,
    RaiseHandView,
    RevokeFloorView,
    SessionDetailView,
    SessionEndView,
    SessionJoinView,
    SessionListCreateView,
    SessionLookupView,
    SessionQaModeView,
    SessionQueueView,
    SessionStartView,
    SessionStopView,
    SpeakView,
)

urlpatterns = [
    path("", SessionListCreateView.as_view(), name="session-list-create"),
    path("lookup/", SessionLookupView.as_view(), name="session-lookup"),
    path("<int:pk>/", SessionDetailView.as_view(), name="session-detail"),
    path("<int:pk>/start/", SessionStartView.as_view(), name="session-start"),
    path("<int:pk>/stop/", SessionStopView.as_view(), name="session-stop"),
    path("<int:pk>/end/", SessionEndView.as_view(), name="session-end"),
    path("<int:pk>/join/", SessionJoinView.as_view(), name="session-join"),
    path("<int:pk>/qa-mode/", SessionQaModeView.as_view(), name="session-qa-mode"),
    path("<int:pk>/raise-hand/", RaiseHandView.as_view(), name="session-raise-hand"),
    path("<int:pk>/lower-hand/", LowerHandView.as_view(), name="session-lower-hand"),
    path("<int:pk>/speak/", SpeakView.as_view(), name="session-speak"),
    path("<int:pk>/queue/", SessionQueueView.as_view(), name="session-queue"),
    path("<int:pk>/grant-floor/", GrantFloorView.as_view(), name="session-grant-floor"),
    path("<int:pk>/revoke-floor/", RevokeFloorView.as_view(), name="session-revoke-floor"),
]
