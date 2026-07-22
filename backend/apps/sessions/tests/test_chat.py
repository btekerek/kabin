"""
Chat: REST send/list for the two scopes (see Message model) - general
(guide + every interpreter in the session) and per-channel (only the
interpreter(s) holding a claim on that channel) - plus WebSocket tests
for both consumers' connect-time auth and broadcast-on-send. Listeners
are never chat participants.
"""

import pytest
from channels.routing import URLRouter
from channels.testing import WebsocketCommunicator
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.realtime.routing import websocket_urlpatterns
from apps.sessions.models import Message

pytestmark = pytest.mark.django_db

application = URLRouter(websocket_urlpatterns)


@pytest.fixture
def guide():
    user = User(email="guide@example.com", username="guide")
    user.set_password("password123!")
    user.save()
    return user


@pytest.fixture
def other_guide():
    user = User(email="other-guide@example.com", username="other-guide")
    user.set_password("password123!")
    user.save()
    return user


@pytest.fixture
def interpreter():
    user = User(email="interpreter@example.com", username="interpreter")
    user.set_password("password123!")
    user.save()
    return user


@pytest.fixture
def interpreter2():
    user = User(email="interpreter2@example.com", username="interpreter2")
    user.set_password("password123!")
    user.save()
    return user


def _authed_client(user):
    client = APIClient()
    client.force_authenticate(user=user)
    return client


@pytest.fixture
def session_with_channels(guide):
    return (
        _authed_client(guide)
        .post(
            "/api/sessions/",
            {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr", "fr"]},
            format="json",
        )
        .data
    )


def _channel(session, language):
    return next(c for c in session["channels"] if c["language"] == language)


def _join(user, channel):
    return _authed_client(user).post(
        "/api/channels/join/", {"interpreter_code": channel["interpreter_code"]}, format="json"
    )


# --- General chat (guide + every interpreter in the session) ---


def test_guide_can_send_and_list_general_messages(guide, session_with_channels):
    client = _authed_client(guide)
    send = client.post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "welcome everyone"},
        format="json",
    )
    assert send.status_code == status.HTTP_201_CREATED
    assert send.data["sender_kind"] == "guide"
    assert send.data["sender_name"] == "guide"
    assert send.data["channel"] is None

    history = client.get(f"/api/sessions/{session_with_channels['id']}/messages/")
    assert history.status_code == status.HTTP_200_OK
    assert [m["body"] for m in history.data] == ["welcome everyone"]


def test_non_owner_guide_cannot_send_general(other_guide, session_with_channels):
    response = _authed_client(other_guide).post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "hi"},
        format="json",
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_interpreter_with_active_claim_can_send_general(interpreter, session_with_channels):
    _join(interpreter, _channel(session_with_channels, "tr"))

    response = _authed_client(interpreter).post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "translating now"},
        format="json",
    )
    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["sender_kind"] == "interpreter"


def test_interpreter_without_claim_cannot_send_general(interpreter, session_with_channels):
    response = _authed_client(interpreter).post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "hi"},
        format="json",
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_anonymous_cannot_send_or_list_general(session_with_channels):
    client = APIClient()
    send = client.post(
        f"/api/sessions/{session_with_channels['id']}/messages/", {"body": "hi"}, format="json"
    )
    assert send.status_code == status.HTTP_401_UNAUTHORIZED

    history = client.get(f"/api/sessions/{session_with_channels['id']}/messages/")
    assert history.status_code == status.HTTP_401_UNAUTHORIZED


def test_general_send_rejects_ended_session(guide, session_with_channels):
    client = _authed_client(guide)
    client.post(f"/api/sessions/{session_with_channels['id']}/start/")
    client.post(f"/api/sessions/{session_with_channels['id']}/end/")

    response = client.post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "hi"},
        format="json",
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "SESSION_ENDED"


def test_general_history_excludes_channel_messages(interpreter, session_with_channels):
    tr_channel = _channel(session_with_channels, "tr")
    _join(interpreter, tr_channel)
    client = _authed_client(interpreter)

    client.post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "general message"},
        format="json",
    )
    client.post(
        f"/api/channels/{tr_channel['id']}/messages/",
        {"body": "channel message"},
        format="json",
    )

    history = client.get(f"/api/sessions/{session_with_channels['id']}/messages/")
    assert [m["body"] for m in history.data] == ["general message"]


def test_general_message_history_is_chronological(guide, session_with_channels):
    client = _authed_client(guide)
    client.post(
        f"/api/sessions/{session_with_channels['id']}/messages/", {"body": "first"}, format="json"
    )
    client.post(
        f"/api/sessions/{session_with_channels['id']}/messages/", {"body": "second"}, format="json"
    )

    history = client.get(f"/api/sessions/{session_with_channels['id']}/messages/")
    assert [m["body"] for m in history.data] == ["first", "second"]
    assert (
        Message.objects.filter(session_id=session_with_channels["id"], channel__isnull=True).count()
        == 2
    )


def test_general_message_history_limit_returns_most_recent(guide, session_with_channels):
    client = _authed_client(guide)
    for body in ["first", "second", "third"]:
        client.post(
            f"/api/sessions/{session_with_channels['id']}/messages/",
            {"body": body},
            format="json",
        )

    history = client.get(f"/api/sessions/{session_with_channels['id']}/messages/", {"limit": 2})
    assert history.status_code == status.HTTP_200_OK
    assert [m["body"] for m in history.data] == ["second", "third"]


def test_general_message_history_before_id_pages_backwards(guide, session_with_channels):
    client = _authed_client(guide)
    ids = []
    for body in ["first", "second", "third"]:
        response = client.post(
            f"/api/sessions/{session_with_channels['id']}/messages/",
            {"body": body},
            format="json",
        )
        ids.append(response.data["id"])

    history = client.get(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"before_id": ids[2]},
    )
    assert [m["body"] for m in history.data] == ["first", "second"]


def test_general_message_history_before_unknown_id_404s(guide, session_with_channels):
    client = _authed_client(guide)
    history = client.get(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"before_id": 999999},
    )
    assert history.status_code == status.HTTP_404_NOT_FOUND


# --- Per-channel chat (only interpreters holding a claim on that channel) ---


def test_channel_interpreter_can_send_and_list(interpreter, session_with_channels):
    tr_channel = _channel(session_with_channels, "tr")
    _join(interpreter, tr_channel)
    client = _authed_client(interpreter)

    send = client.post(
        f"/api/channels/{tr_channel['id']}/messages/", {"body": "relay note"}, format="json"
    )
    assert send.status_code == status.HTTP_201_CREATED
    assert send.data["sender_kind"] == "interpreter"
    assert send.data["channel"] == tr_channel["id"]

    history = client.get(f"/api/channels/{tr_channel['id']}/messages/")
    assert [m["body"] for m in history.data] == ["relay note"]


def test_channel_guide_cannot_send(guide, session_with_channels):
    tr_channel = _channel(session_with_channels, "tr")
    response = _authed_client(guide).post(
        f"/api/channels/{tr_channel['id']}/messages/", {"body": "hi"}, format="json"
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_channel_interpreter_on_other_channel_cannot_send(interpreter, session_with_channels):
    tr_channel = _channel(session_with_channels, "tr")
    fr_channel = _channel(session_with_channels, "fr")
    _join(interpreter, fr_channel)

    response = _authed_client(interpreter).post(
        f"/api/channels/{tr_channel['id']}/messages/", {"body": "hi"}, format="json"
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_channel_interpreter_without_claim_cannot_send(interpreter, session_with_channels):
    tr_channel = _channel(session_with_channels, "tr")
    response = _authed_client(interpreter).post(
        f"/api/channels/{tr_channel['id']}/messages/", {"body": "hi"}, format="json"
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_channel_two_interpreters_on_same_channel_share_messages(
    interpreter, interpreter2, session_with_channels
):
    tr_channel = _channel(session_with_channels, "tr")
    _join(interpreter, tr_channel)
    _join(interpreter2, tr_channel)

    _authed_client(interpreter).post(
        f"/api/channels/{tr_channel['id']}/messages/", {"body": "from one"}, format="json"
    )

    history = _authed_client(interpreter2).get(f"/api/channels/{tr_channel['id']}/messages/")
    assert [m["body"] for m in history.data] == ["from one"]


def test_channel_send_rejects_ended_session(interpreter, session_with_channels):
    tr_channel = _channel(session_with_channels, "tr")
    _join(interpreter, tr_channel)
    client = _authed_client(interpreter)
    guide_client = APIClient()
    guide_client.force_authenticate(user=User.objects.get(email="guide@example.com"))
    guide_client.post(f"/api/sessions/{session_with_channels['id']}/end/")

    response = client.post(
        f"/api/channels/{tr_channel['id']}/messages/", {"body": "hi"}, format="json"
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "SESSION_ENDED"


# --- WebSocket: general chat ---


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_general_rejects_connection_with_no_credentials(session_with_channels):
    communicator = WebsocketCommunicator(
        application, f"/ws/sessions/{session_with_channels['id']}/chat/"
    )
    connected, _ = await communicator.connect()
    assert not connected


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_general_guide_owner_can_connect(guide, session_with_channels):
    from channels.db import database_sync_to_async
    from rest_framework_simplejwt.tokens import RefreshToken

    @database_sync_to_async
    def _access_token():
        return str(RefreshToken.for_user(guide).access_token)

    token = await _access_token()
    communicator = WebsocketCommunicator(
        application, f"/ws/sessions/{session_with_channels['id']}/chat/?token={token}"
    )
    connected, _ = await communicator.connect()
    assert connected
    await communicator.disconnect()


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_general_receives_broadcast_message(guide, interpreter, session_with_channels):
    from channels.db import database_sync_to_async
    from rest_framework_simplejwt.tokens import RefreshToken

    @database_sync_to_async
    def _join_and_token():
        _join(interpreter, _channel(session_with_channels, "tr"))
        return str(RefreshToken.for_user(interpreter).access_token)

    @database_sync_to_async
    def _send():
        return _authed_client(guide).post(
            f"/api/sessions/{session_with_channels['id']}/messages/",
            {"body": "hello general"},
            format="json",
        )

    token = await _join_and_token()
    communicator = WebsocketCommunicator(
        application, f"/ws/sessions/{session_with_channels['id']}/chat/?token={token}"
    )
    connected, _ = await communicator.connect()
    assert connected

    send_response = await _send()
    assert send_response.status_code == status.HTTP_201_CREATED

    received = await communicator.receive_json_from()
    assert received["body"] == "hello general"

    await communicator.disconnect()


# --- WebSocket: per-channel chat ---


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_channel_guide_cannot_connect(guide, session_with_channels):
    from channels.db import database_sync_to_async
    from rest_framework_simplejwt.tokens import RefreshToken

    @database_sync_to_async
    def _access_token():
        return str(RefreshToken.for_user(guide).access_token)

    tr_channel = _channel(session_with_channels, "tr")
    token = await _access_token()
    communicator = WebsocketCommunicator(
        application, f"/ws/channels/{tr_channel['id']}/chat/?token={token}"
    )
    connected, _ = await communicator.connect()
    assert not connected


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_channel_receives_broadcast_message(
    interpreter, interpreter2, session_with_channels
):
    from channels.db import database_sync_to_async
    from rest_framework_simplejwt.tokens import RefreshToken

    tr_channel = _channel(session_with_channels, "tr")

    @database_sync_to_async
    def _join_both_and_token():
        _join(interpreter, tr_channel)
        _join(interpreter2, tr_channel)
        return str(RefreshToken.for_user(interpreter2).access_token)

    @database_sync_to_async
    def _send():
        return _authed_client(interpreter).post(
            f"/api/channels/{tr_channel['id']}/messages/",
            {"body": "hello channel"},
            format="json",
        )

    token = await _join_both_and_token()
    communicator = WebsocketCommunicator(
        application, f"/ws/channels/{tr_channel['id']}/chat/?token={token}"
    )
    connected, _ = await communicator.connect()
    assert connected

    send_response = await _send()
    assert send_response.status_code == status.HTTP_201_CREATED

    received = await communicator.receive_json_from()
    assert received["body"] == "hello channel"

    await communicator.disconnect()
