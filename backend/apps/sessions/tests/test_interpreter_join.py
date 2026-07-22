"""
Interpreter channel-claiming flow: code -> claim -> Agora publisher token.

Unlike listener join, these endpoints require a real authenticated
account - any account may claim a channel, so tests
force_authenticate rather than hitting them anonymously.
"""

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.sessions.models import ChannelInterpreter

pytestmark = pytest.mark.django_db


@pytest.fixture
def guide():
    user = User(email="guide@example.com", username="guide")
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
def other_interpreter():
    user = User(email="other-interpreter@example.com", username="other-interpreter")
    user.set_password("password123!")
    user.save()
    return user


def _authed_client(user):
    client = APIClient()
    client.force_authenticate(user=user)
    return client


@pytest.fixture
def session_with_channels(guide):
    response = _authed_client(guide).post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr"]},
        format="json",
    )
    return response.data


def test_interpreter_can_claim_channel(interpreter, session_with_channels):
    code = session_with_channels["channels"][1]["interpreter_code"]
    response = _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    assert response.status_code == status.HTTP_200_OK
    assert (
        response.data["agora_channel_name"]
        == f"kabin-ch-{session_with_channels['channels'][1]['id']}"
    )
    assert response.data["agora_token"]
    assert ChannelInterpreter.objects.filter(interpreter=interpreter).exists()


def test_session_owner_can_also_claim_a_channel(guide, session_with_channels):
    # There's no fixed account role (see permissions.py) - the same
    # account that owns a session (its guide) can also claim one of its
    # own channels as an interpreter.
    code = session_with_channels["channels"][1]["interpreter_code"]
    response = _authed_client(guide).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )
    assert response.status_code == status.HTTP_200_OK
    assert ChannelInterpreter.objects.filter(interpreter=guide).exists()


def test_unknown_code_returns_channel_not_found(interpreter):
    response = _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": "XX999999"}, format="json"
    )
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert response.data["code"] == "CHANNEL_NOT_FOUND"


def test_same_interpreter_rejoining_refreshes_without_conflict(interpreter, session_with_channels):
    code = session_with_channels["channels"][1]["interpreter_code"]
    client = _authed_client(interpreter)

    first = client.post("/api/channels/join/", {"interpreter_code": code}, format="json")
    second = client.post("/api/channels/join/", {"interpreter_code": code}, format="json")

    assert first.status_code == status.HTTP_200_OK
    assert second.status_code == status.HTTP_200_OK
    assert (
        ChannelInterpreter.objects.filter(
            channel_id=session_with_channels["channels"][1]["id"]
        ).count()
        == 1
    )


def test_second_interpreter_can_also_claim_a_staffed_channel(
    interpreter, other_interpreter, session_with_channels
):
    code = session_with_channels["channels"][1]["interpreter_code"]
    _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    response = _authed_client(other_interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    assert response.status_code == status.HTTP_200_OK
    assert (
        ChannelInterpreter.objects.filter(
            channel_id=session_with_channels["channels"][1]["id"]
        ).count()
        == 2
    )


def test_join_rejects_ended_session(guide, interpreter, session_with_channels):
    guide_client = _authed_client(guide)
    guide_client.post(f"/api/sessions/{session_with_channels['id']}/start/")
    guide_client.post(f"/api/sessions/{session_with_channels['id']}/end/")

    code = session_with_channels["channels"][1]["interpreter_code"]
    response = _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "SESSION_ENDED"


def test_leave_releases_claim(interpreter, session_with_channels):
    code = session_with_channels["channels"][1]["interpreter_code"]
    client = _authed_client(interpreter)
    client.post("/api/channels/join/", {"interpreter_code": code}, format="json")

    response = client.post("/api/channels/leave/", {"interpreter_code": code}, format="json")

    assert response.status_code == status.HTTP_204_NO_CONTENT
    assert not ChannelInterpreter.objects.filter(interpreter=interpreter).exists()


def test_leave_is_a_no_op_when_not_holding_the_channel(interpreter, session_with_channels):
    code = session_with_channels["channels"][1]["interpreter_code"]
    response = _authed_client(interpreter).post(
        "/api/channels/leave/", {"interpreter_code": code}, format="json"
    )
    assert response.status_code == status.HTTP_204_NO_CONTENT


def test_leave_does_not_release_someone_elses_claim(
    interpreter, other_interpreter, session_with_channels
):
    code = session_with_channels["channels"][1]["interpreter_code"]
    _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    _authed_client(other_interpreter).post(
        "/api/channels/leave/", {"interpreter_code": code}, format="json"
    )

    assert ChannelInterpreter.objects.filter(interpreter=interpreter).exists()


def test_claiming_a_target_channel_defaults_relay_to_source(interpreter, session_with_channels):
    # channels[0] is the source (en); channels[1] is the target (tr) - see
    # session_with_channels fixture, which mirrors SessionListCreateView's
    # creation order.
    source_channel = session_with_channels["channels"][0]
    target_code = session_with_channels["channels"][1]["interpreter_code"]

    response = _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": target_code}, format="json"
    )

    assert response.status_code == status.HTTP_200_OK
    relay = response.data["relay"]
    assert relay is not None
    assert relay["agora_channel_name"] == f"kabin-ch-{source_channel['id']}"
    assert relay["agora_token"]
    assert relay["channel"]["id"] == source_channel["id"]
    assert relay["channel"]["is_source"] is True
    # ListenerChannelSerializer shape - no interpreter_code leaked to a
    # channel that isn't this interpreter's own.
    assert "interpreter_code" not in relay["channel"]


def test_source_channel_has_no_interpreter_code_to_claim_with(interpreter, session_with_channels):
    # There's no scenario where an interpreter relays the source channel
    # into itself, so the source channel is never issued an
    # interpreter_code at all (see models.py) - nothing to join with.
    source_channel = session_with_channels["channels"][0]
    assert source_channel["is_source"] is True
    assert source_channel["interpreter_code"] is None
