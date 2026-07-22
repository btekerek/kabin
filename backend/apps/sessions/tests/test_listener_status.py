"""
ListenerStatusConsumer: read-only session_status push for a listener on
one channel, reusing the same "channel-<id>-mic" group interpreters'
mic presence already broadcasts to - see consumers.py.
"""

import uuid

import pytest
from channels.routing import URLRouter
from channels.testing import WebsocketCommunicator
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.realtime.routing import websocket_urlpatterns

pytestmark = pytest.mark.django_db

application = URLRouter(websocket_urlpatterns)


@pytest.fixture
def guide():
    user = User(email="guide@example.com", username="guide")
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


def _source_channel(session):
    return next(c for c in session["channels"] if c["is_source"])


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_rejects_unknown_listener_uuid(session_with_channels):
    channel = _source_channel(session_with_channels)
    communicator = WebsocketCommunicator(
        application,
        f"/ws/channels/{channel['id']}/listener-status/?listener_uuid={uuid.uuid4()}",
    )
    connected, _ = await communicator.connect()
    assert not connected


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_rejects_connection_with_no_credentials(session_with_channels):
    channel = _source_channel(session_with_channels)
    communicator = WebsocketCommunicator(
        application, f"/ws/channels/{channel['id']}/listener-status/"
    )
    connected, _ = await communicator.connect()
    assert not connected


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_listener_on_channel_can_connect_and_receives_session_status(
    guide, session_with_channels
):
    from channels.db import database_sync_to_async

    channel = _source_channel(session_with_channels)
    listener_uuid = str(uuid.uuid4())

    @database_sync_to_async
    def _join():
        return APIClient().post(
            f"/api/sessions/{session_with_channels['id']}/join/",
            {"listener_uuid": listener_uuid, "channel_id": channel["id"]},
            format="json",
        )

    @database_sync_to_async
    def _end_session():
        return _authed_client(guide).post(f"/api/sessions/{session_with_channels['id']}/end/")

    await _join()

    communicator = WebsocketCommunicator(
        application,
        f"/ws/channels/{channel['id']}/listener-status/?listener_uuid={listener_uuid}",
    )
    connected, _ = await communicator.connect()
    assert connected

    end_response = await _end_session()
    assert end_response.status_code == 200

    received = await communicator.receive_json_from()
    assert received == {"type": "session_status", "status": "ended"}

    await communicator.disconnect()
