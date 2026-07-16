"""
Interpreter channel-claiming flow: code -> claim -> Agora publisher token.

Unlike listener join, these endpoints require a real authenticated
Interpreter account (see ADR-003), so tests force_authenticate rather
than hitting them anonymously.
"""

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.sessions.models import ChannelInterpreter

pytestmark = pytest.mark.django_db


@pytest.fixture
def guide():
    user = User(email="guide@example.com", username="guide", role=User.Role.GUIDE)
    user.set_password("password123!")
    user.save()
    return user


@pytest.fixture
def interpreter():
    user = User(email="interpreter@example.com", username="interpreter", role=User.Role.INTERPRETER)
    user.set_password("password123!")
    user.save()
    return user


@pytest.fixture
def other_interpreter():
    user = User(
        email="other-interpreter@example.com",
        username="other-interpreter",
        role=User.Role.INTERPRETER,
    )
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
    code = session_with_channels["channels"][0]["interpreter_code"]
    response = _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    assert response.status_code == status.HTTP_200_OK
    assert (
        response.data["agora_channel_name"]
        == f"kabin-ch-{session_with_channels['channels'][0]['id']}"
    )
    assert response.data["agora_token"]
    assert ChannelInterpreter.objects.filter(interpreter=interpreter).exists()


def test_non_interpreter_cannot_claim_channel(guide, session_with_channels):
    code = session_with_channels["channels"][0]["interpreter_code"]
    response = _authed_client(guide).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_unknown_code_returns_channel_not_found(interpreter):
    response = _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": "XX999999"}, format="json"
    )
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert response.data["code"] == "CHANNEL_NOT_FOUND"


def test_same_interpreter_rejoining_refreshes_without_conflict(interpreter, session_with_channels):
    code = session_with_channels["channels"][0]["interpreter_code"]
    client = _authed_client(interpreter)

    first = client.post("/api/channels/join/", {"interpreter_code": code}, format="json")
    second = client.post("/api/channels/join/", {"interpreter_code": code}, format="json")

    assert first.status_code == status.HTTP_200_OK
    assert second.status_code == status.HTTP_200_OK
    assert (
        ChannelInterpreter.objects.filter(
            channel_id=session_with_channels["channels"][0]["id"]
        ).count()
        == 1
    )


def test_different_interpreter_rejected_while_channel_staffed(
    interpreter, other_interpreter, session_with_channels
):
    code = session_with_channels["channels"][0]["interpreter_code"]
    _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    response = _authed_client(other_interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    assert response.status_code == status.HTTP_409_CONFLICT
    assert response.data["code"] == "CHANNEL_ALREADY_STAFFED"


def test_join_rejects_ended_session(guide, interpreter, session_with_channels):
    guide_client = _authed_client(guide)
    guide_client.post(f"/api/sessions/{session_with_channels['id']}/start/")
    guide_client.post(f"/api/sessions/{session_with_channels['id']}/end/")

    code = session_with_channels["channels"][0]["interpreter_code"]
    response = _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "SESSION_ENDED"


def test_leave_releases_claim(interpreter, session_with_channels):
    code = session_with_channels["channels"][0]["interpreter_code"]
    client = _authed_client(interpreter)
    client.post("/api/channels/join/", {"interpreter_code": code}, format="json")

    response = client.post("/api/channels/leave/", {"interpreter_code": code}, format="json")

    assert response.status_code == status.HTTP_204_NO_CONTENT
    assert not ChannelInterpreter.objects.filter(interpreter=interpreter).exists()


def test_leave_is_a_no_op_when_not_holding_the_channel(interpreter, session_with_channels):
    code = session_with_channels["channels"][0]["interpreter_code"]
    response = _authed_client(interpreter).post(
        "/api/channels/leave/", {"interpreter_code": code}, format="json"
    )
    assert response.status_code == status.HTTP_204_NO_CONTENT


def test_leave_does_not_release_someone_elses_claim(
    interpreter, other_interpreter, session_with_channels
):
    code = session_with_channels["channels"][0]["interpreter_code"]
    _authed_client(interpreter).post(
        "/api/channels/join/", {"interpreter_code": code}, format="json"
    )

    _authed_client(other_interpreter).post(
        "/api/channels/leave/", {"interpreter_code": code}, format="json"
    )

    assert ChannelInterpreter.objects.filter(interpreter=interpreter).exists()
