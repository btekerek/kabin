"""
Django Channels consumers.

ChatConsumers are push-only from the client's perspective. They never
accept a "send message" action; REST (apps.sessions.views) is the only
write path and pushes to a consumer's group after creating each
Message. Every consumer added here must authorize on connect the same
way REST does for the equivalent action.
"""

from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import AccessToken

from apps.accounts.models import User
from apps.sessions.models import ChannelInterpreter, Session


def _user_from_token(token):
    """Resolves the query-string `?token=` credential shared by every
    consumer below - auth travels in the URL, not a header, since
    neither browsers nor Flutter can attach custom headers to a
    WebSocket handshake (see ADR-005).
    """
    if not token:
        return None
    try:
        access = AccessToken(token)
        return User.objects.get(pk=access["user_id"])
    except (TokenError, User.DoesNotExist, KeyError):
        return None


class SessionChatConsumer(AsyncJsonWebsocketConsumer):
    """Relays "general" chat messages (guide + every interpreter in the
    session) to every connected client.
    """

    async def connect(self):
        self.session_id = self.scope["url_route"]["kwargs"]["session_id"]
        self.group_name = f"session-{self.session_id}-chat"

        if not await self._authorize():
            await self.close(code=4403)
            return

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def chat_message(self, event):
        await self.send_json(event["message"])

    @database_sync_to_async
    def _authorize(self):
        try:
            session = Session.objects.get(pk=self.session_id)
        except (Session.DoesNotExist, ValueError):
            return False

        query_params = parse_qs(self.scope["query_string"].decode())
        user = _user_from_token(query_params.get("token", [None])[0])
        if user is None:
            return False
        if session.owner_id == user.id:
            return True
        return ChannelInterpreter.objects.filter(
            channel__session=session, interpreter=user
        ).exists()


class ChannelChatConsumer(AsyncJsonWebsocketConsumer):
    """Relays per-channel chat messages to only the interpreter(s)
    holding a claim on that channel - not the guide, not interpreters on
    other channels (see Message model).
    """

    async def connect(self):
        self.channel_id = self.scope["url_route"]["kwargs"]["channel_id"]
        self.group_name = f"channel-{self.channel_id}-chat"

        if not await self._authorize():
            await self.close(code=4403)
            return

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def chat_message(self, event):
        await self.send_json(event["message"])

    @database_sync_to_async
    def _authorize(self):
        query_params = parse_qs(self.scope["query_string"].decode())
        user = _user_from_token(query_params.get("token", [None])[0])
        if user is None:
            return False
        return ChannelInterpreter.objects.filter(
            channel_id=self.channel_id, interpreter=user
        ).exists()


class MicPresenceConsumer(AsyncJsonWebsocketConsumer):
    """Relays "my mic is on/off" between interpreters sharing a channel
    (see ADR-008) - purely a relay, no state kept server-side. A client
    that just connected sends `status_request`; whoever's currently live
    replies with `mic_state` again so the newcomer catches up.
    Disconnecting always broadcasts `live: false` for that user, so a
    closed/crashed client can't leave a stale "live" flag on everyone
    else.
    """

    async def connect(self):
        self.channel_id = self.scope["url_route"]["kwargs"]["channel_id"]
        self.group_name = f"channel-{self.channel_id}-mic"

        user = await self._authorize()
        if user is None:
            await self.close(code=4403)
            return
        self.user = user

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)
        if hasattr(self, "user"):
            await self.channel_layer.group_send(
                self.group_name,
                {"type": "mic_state", "user_id": self.user.id, "live": False},
            )

    async def receive_json(self, content, **kwargs):
        message_type = content.get("type")
        if message_type == "mic_state":
            await self.channel_layer.group_send(
                self.group_name,
                {
                    "type": "mic_state",
                    "user_id": self.user.id,
                    "live": bool(content.get("live")),
                },
            )
        elif message_type == "status_request":
            await self.channel_layer.group_send(
                self.group_name,
                {"type": "status_request", "user_id": self.user.id},
            )

    async def mic_state(self, event):
        await self.send_json(
            {"type": "mic_state", "user_id": event["user_id"], "live": event["live"]}
        )

    async def status_request(self, event):
        await self.send_json({"type": "status_request", "user_id": event["user_id"]})

    async def session_status(self, event):
        """Handles a "session_status" group_send from
        _SessionTransitionView.after_transition - pushed to every
        channel of the session, not just this one's own group member.
        """
        await self.send_json({"type": "session_status", "status": event["status"]})

    @database_sync_to_async
    def _authorize(self):
        query_params = parse_qs(self.scope["query_string"].decode())
        user = _user_from_token(query_params.get("token", [None])[0])
        if user is None:
            return None
        if not ChannelInterpreter.objects.filter(
            channel_id=self.channel_id, interpreter=user
        ).exists():
            return None
        return user
