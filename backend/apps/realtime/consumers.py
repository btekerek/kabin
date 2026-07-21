"""
Django Channels consumers.

ChatConsumer is the first real one (see ADR-005) - push-only from the
client's perspective. It never accepts a "send message" action; REST
(apps.sessions.views.MessageListCreateView) is the only write path and
pushes to this consumer's group after creating each Message. Every
consumer added here must authorize on connect the same way REST does
for the equivalent action - see ChatConsumer._authorize for the pattern
other real-time features (mic indicators, etc.) should follow.
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
            # Guide-ness is ownership, interpreter-ness is a channel
            # claim - neither is an account role. Mirrors
            # IsSessionParticipant on the REST side.
            if session.owner_id == user.id:
                return True
            return ChannelInterpreter.objects.filter(
                channel__session=session, interpreter=user
            ).exists()

        if raw_listener_uuid:
            try:
                listener_uuid = uuid_lib.UUID(raw_listener_uuid)
            except ValueError:
                return False
            return ListenerSession.objects.filter(
                session=session, listener_uuid=listener_uuid
            ).exists()

        return False


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
        token = query_params.get("token", [None])[0]
        if not token:
            return None
        try:
            access = AccessToken(token)
            user = User.objects.get(pk=access["user_id"])
        except (TokenError, User.DoesNotExist, KeyError):
            return None
        if not ChannelInterpreter.objects.filter(
            channel_id=self.channel_id, interpreter=user
        ).exists():
            return None
        return user
