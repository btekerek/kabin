"""WebSocket URL routing. See ChatConsumer (consumers.py) and ADR-005."""

from django.urls import re_path

from apps.realtime.consumers import ChatConsumer, MicPresenceConsumer

websocket_urlpatterns = [
    re_path(r"^ws/sessions/(?P<session_id>\d+)/chat/$", ChatConsumer.as_asgi()),
    re_path(
        r"^ws/channels/(?P<channel_id>\d+)/mic-presence/$",
        MicPresenceConsumer.as_asgi(),
    ),
]
