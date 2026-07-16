"""
Django Channels consumers.

ChatConsumer is the first real one (see ADR-005) - push-only from the
client's perspective. It never accepts a "send message" action; REST
(apps.sessions.views.MessageListCreateView) is the only write path and
pushes to this consumer's group after creating each Message. Every
consumer added here must authorize on connect the same way REST does
for the equivalent action - see ChatConsumer._authorize for the pattern
other real-time features (queue/floor updates, mic indicators) should
follow.
"""

import uuid as uuid_lib
from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import AccessToken

from apps.accounts.models import User
from apps.sessions.models import ChannelInterpreter, ListenerSession, Session


class ChatConsumer(AsyncJsonWebsocketConsumer):
    """Relays chat messages for one session to every connected client.

    Auth travels in the connection URL's query string, not a header -
    see ADR-005 for why (browsers/Flutter can't attach custom headers to
    a WS handshake) and the tradeoff that implies. `?token=<access
    token>` for guide/interpreter, `?listener_uuid=<uuid>` for listeners.
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
        """Handles a "chat.message" group_send from MessageListCreateView."""
        await self.send_json(event["message"])

    @database_sync_to_async
    def _authorize(self):
        try:
            session = Session.objects.get(pk=self.session_id)
        except (Session.DoesNotExist, ValueError):
            return False

        query_params = parse_qs(self.scope["query_string"].decode())
        token = query_params.get("token", [None])[0]
        raw_listener_uuid = query_params.get("listener_uuid", [None])[0]

        if token:
            try:
                access = AccessToken(token)
                user = User.objects.get(pk=access["user_id"])
            except (TokenError, User.DoesNotExist, KeyError):
                return False
            if user.role == User.Role.GUIDE:
                return session.owner_id == user.id
            if user.role == User.Role.INTERPRETER:
                return ChannelInterpreter.objects.filter(
                    channel__session=session, interpreter=user
                ).exists()
            return False

        if raw_listener_uuid:
            try:
                listener_uuid = uuid_lib.UUID(raw_listener_uuid)
            except ValueError:
                return False
            return ListenerSession.objects.filter(
                session=session, listener_uuid=listener_uuid
            ).exists()

        return False
