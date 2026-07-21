"""
Chat: REST send/list for all three sender kinds (see ADR-005), plus the
first WebSocket tests in this codebase for ChatConsumer's connect-time
auth and broadcast-on-send.
"""

import uuid

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
            {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr"]},
            format="json",
        )
        .data
    )


def test_guide_can_send_and_list_messages(guide, session_with_channels):
    client = _authed_client(guide)
    send = client.post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "welcome everyone"},
        format="json",
    )
    assert send.status_code == status.HTTP_201_CREATED
    assert send.data["sender_kind"] == "guide"

    history = client.get(f"/api/sessions/{session_with_channels['id']}/messages/")
    assert history.status_code == status.HTTP_200_OK
    assert [m["body"] for m in history.data] == ["welcome everyone"]


def test_non_owner_guide_cannot_send(other_guide, session_with_channels):
    response = _authed_client(other_guide).post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "hi"},
        format="json",
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_interpreter_with_active_claim_can_send(interpreter, session_with_channels):
    code = session_with_channels["channels"][1]["interpreter_code"]
    _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    response = _authed_client(interpreter).post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "translating now"},
        format="json",
    )
    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["sender_kind"] == "interpreter"


def test_interpreter_without_claim_cannot_send(interpreter, session_with_channels):
    response = _authed_client(interpreter).post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "hi"},
        format="json",
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_listener_with_membership_can_send_and_list(session_with_channels):
    listener_uuid = str(uuid.uuid4())
    APIClient().post(
        f"/api/sessions/{session_with_channels['id']}/join/",
        {
            "listener_uuid": listener_uuid,
            "channel_id": session_with_channels["channels"][0]["id"],
        },
        format="json",
    )

    send = APIClient().post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "great session", "listener_uuid": listener_uuid},
        format="json",
    )
    assert send.status_code == status.HTTP_201_CREATED
    assert send.data["sender_kind"] == "listener"
    assert send.data["sender_listener_uuid"] == listener_uuid

    history = APIClient().get(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"listener_uuid": listener_uuid},
    )
    assert history.status_code == status.HTTP_200_OK
    assert len(history.data) == 1


def test_listener_without_membership_cannot_send(session_with_channels):
    response = APIClient().post(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"body": "hi", "listener_uuid": str(uuid.uuid4())},
        format="json",
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_send_rejects_ended_session(guide, session_with_channels):
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


def test_message_history_is_chronological(guide, session_with_channels):
    client = _authed_client(guide)
    client.post(
        f"/api/sessions/{session_with_channels['id']}/messages/", {"body": "first"}, format="json"
    )
    client.post(
        f"/api/sessions/{session_with_channels['id']}/messages/", {"body": "second"}, format="json"
    )

    history = client.get(f"/api/sessions/{session_with_channels['id']}/messages/")
    assert [m["body"] for m in history.data] == ["first", "second"]
    assert Message.objects.filter(session_id=session_with_channels["id"]).count() == 2


def test_message_history_limit_returns_most_recent(guide, session_with_channels):
    client = _authed_client(guide)
    for body in ["first", "second", "third"]:
        client.post(
            f"/api/sessions/{session_with_channels['id']}/messages/",
            {"body": body},
            format="json",
        )

    history = client.get(f"/api/sessions/{session_with_channels['id']}/messages/", {"limit": 2})
    assert history.status_code == status.HTTP_200_OK
    # Still the most recent 2, in chronological order - not the first 2.
    assert [m["body"] for m in history.data] == ["second", "third"]


def test_message_history_before_id_pages_backwards(guide, session_with_channels):
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


def test_message_history_before_id_combines_with_limit(guide, session_with_channels):
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
        {"before_id": ids[2], "limit": 1},
    )
    assert [m["body"] for m in history.data] == ["second"]


def test_message_history_before_unknown_id_404s(guide, session_with_channels):
    client = _authed_client(guide)
    history = client.get(
        f"/api/sessions/{session_with_channels['id']}/messages/",
        {"before_id": 999999},
    )
    assert history.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_listener_receives_broadcast_message(session_with_channels):
    from channels.db import database_sync_to_async

    listener_uuid = str(uuid.uuid4())

    @database_sync_to_async
    def _join():
        return APIClient().post(
            f"/api/sessions/{session_with_channels['id']}/join/",
            {
                "listener_uuid": listener_uuid,
                "channel_id": session_with_channels["channels"][0]["id"],
            },
            format="json",
        )

    @database_sync_to_async
    def _send():
        return APIClient().post(
            f"/api/sessions/{session_with_channels['id']}/messages/",
            {"body": "hello from REST", "listener_uuid": listener_uuid},
            format="json",
        )

    await _join()

    communicator = WebsocketCommunicator(
        application,
        f"/ws/sessions/{session_with_channels['id']}/chat/?listener_uuid={listener_uuid}",
    )
    connected, _ = await communicator.connect()
    assert connected

    send_response = await _send()
    assert send_response.status_code == status.HTTP_201_CREATED

    received = await communicator.receive_json_from()
    assert received["body"] == "hello from REST"

    await communicator.disconnect()


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_rejects_unknown_listener_uuid(session_with_channels):
    communicator = WebsocketCommunicator(
        application,
        f"/ws/sessions/{session_with_channels['id']}/chat/?listener_uuid={uuid.uuid4()}",
    )
    connected, _ = await communicator.connect()
    assert not connected


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_rejects_connection_with_no_credentials(session_with_channels):
    communicator = WebsocketCommunicator(
        application, f"/ws/sessions/{session_with_channels['id']}/chat/"
    )
    connected, _ = await communicator.connect()
    assert not connected


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_guide_owner_can_connect(guide, session_with_channels):
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
