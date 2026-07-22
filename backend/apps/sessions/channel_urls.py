"""Channel-scoped routes for interpreters - code-based, not session-pk-based.

An interpreter's code already identifies one specific channel, so these
live at /api/channels/ rather than nested under a session id the
interpreter may not even know.
"""

from django.urls import path

from apps.sessions.views import (
    ChannelJoinView,
    ChannelLeaveView,
    ChannelMessageListCreateView,
    ChannelRelayView,
    ChannelSwitchView,
)

urlpatterns = [
    path("join/", ChannelJoinView.as_view(), name="channel-join"),
    path("leave/", ChannelLeaveView.as_view(), name="channel-leave"),
    path("<int:pk>/messages/", ChannelMessageListCreateView.as_view(), name="channel-messages"),
    path("<int:pk>/relay/", ChannelRelayView.as_view(), name="channel-relay"),
    path("<int:pk>/switch/", ChannelSwitchView.as_view(), name="channel-switch"),
]
