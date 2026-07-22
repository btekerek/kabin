"""WebSocket URL routing. See consumers.py and ADR-005."""

from django.urls import re_path

from apps.realtime.consumers import (
    ChannelChatConsumer,
    ListenerStatusConsumer,
    MicPresenceConsumer,
    SessionChatConsumer,
)

websocket_urlpatterns = [
    re_path(r"^ws/sessions/(?P<session_id>\d+)/chat/$", SessionChatConsumer.as_asgi()),
    re_path(r"^ws/channels/(?P<channel_id>\d+)/chat/$", ChannelChatConsumer.as_asgi()),
    re_path(
        r"^ws/channels/(?P<channel_id>\d+)/mic-presence/$",
        MicPresenceConsumer.as_asgi(),
    ),
    re_path(
        r"^ws/channels/(?P<channel_id>\d+)/listener-status/$",
        ListenerStatusConsumer.as_asgi(),
    ),
]
