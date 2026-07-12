"""
Listener join flow: PIN lookup -> channel pick -> Agora audience token.

Both endpoints are unauthenticated (listeners aren't Django users), so
these tests hit them with a plain APIClient, no force_authenticate.
"""

import uuid

import pytest
from django.test import override_settings
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.sessions.models import ListenerSession

pytestmark = pytest.mark.django_db


@pytest.fixture
def guide():
    user = User(email="guide@example.com", username="guide", role=User.Role.GUIDE)
    user.set_password("password123!")
    user.save()
    return user


@pytest.fixture
def session_with_channels(guide):
    client = APIClient()
    client.force_authenticate(user=guide)
    response = client.post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr"]},
        format="json",
    )
    return response.data


def test_lookup_returns_session_and_channels_without_interpreter_code(session_with_channels):
    client = APIClient()
    response = client.post(
        "/api/sessions/lookup/",
        {"listener_code": session_with_channels["listener_code"]},
        format="json",
    )
    assert response.status_code == status.HTTP_200_OK
    assert response.data["name"] == "Kabin Conf"
    assert response.data["status"] == "not_started"
    assert len(response.data["channels"]) == 2
    for channel in response.data["channels"]:
        assert "interpreter_code" not in channel


def test_lookup_unknown_code_returns_session_not_found():
    client = APIClient()
    response = client.post("/api/sessions/lookup/", {"listener_code": "000000"}, format="json")
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert response.data["code"] == "SESSION_NOT_FOUND"


def test_join_returns_agora_token_and_creates_listener_session(session_with_channels):
    client = APIClient()
    channel_id = session_with_channels["channels"][0]["id"]
    listener_uuid = str(uuid.uuid4())

    response = client.post(
        f"/api/sessions/{session_with_channels['id']}/join/",
        {"listener_uuid": listener_uuid, "channel_id": channel_id},
        format="json",
    )

    assert response.status_code == status.HTTP_200_OK
    assert response.data["agora_channel_name"] == f"kabin-ch-{channel_id}"
    assert response.data["agora_token"]
    assert response.data["channel"]["id"] == channel_id
    assert "interpreter_code" not in response.data["channel"]
    assert ListenerSession.objects.filter(
        session_id=session_with_channels["id"], listener_uuid=listener_uuid
    ).exists()


def test_rejoining_same_listener_switches_channel_without_double_counting(session_with_channels):
    client = APIClient()
    listener_uuid = str(uuid.uuid4())
    first_channel_id = session_with_channels["channels"][0]["id"]
    second_channel_id = session_with_channels["channels"][1]["id"]

    client.post(
        f"/api/sessions/{session_with_channels['id']}/join/",
        {"listener_uuid": listener_uuid, "channel_id": first_channel_id},
        format="json",
    )
    response = client.post(
        f"/api/sessions/{session_with_channels['id']}/join/",
        {"listener_uuid": listener_uuid, "channel_id": second_channel_id},
        format="json",
    )

    assert response.status_code == status.HTTP_200_OK
    assert response.data["channel"]["id"] == second_channel_id
    assert ListenerSession.objects.filter(session_id=session_with_channels["id"]).count() == 1
    assert (
        ListenerSession.objects.get(session_id=session_with_channels["id"]).channel_id
        == second_channel_id
    )


@override_settings(SESSION_LISTENER_CAP_DEFAULT=1)
def test_join_rejects_when_at_capacity(session_with_channels):
    client = APIClient()
    channel_id = session_with_channels["channels"][0]["id"]

    client.post(
        f"/api/sessions/{session_with_channels['id']}/join/",
        {"listener_uuid": str(uuid.uuid4()), "channel_id": channel_id},
        format="json",
    )
    response = client.post(
        f"/api/sessions/{session_with_channels['id']}/join/",
        {"listener_uuid": str(uuid.uuid4()), "channel_id": channel_id},
        format="json",
    )

    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert response.data["code"] == "LISTENER_CAP_REACHED"


def test_join_rejects_ended_session(guide, session_with_channels):
    guide_client = APIClient()
    guide_client.force_authenticate(user=guide)
    guide_client.post(f"/api/sessions/{session_with_channels['id']}/start/")
    guide_client.post(f"/api/sessions/{session_with_channels['id']}/end/")

    client = APIClient()
    response = client.post(
        f"/api/sessions/{session_with_channels['id']}/join/",
        {
            "listener_uuid": str(uuid.uuid4()),
            "channel_id": session_with_channels["channels"][0]["id"],
        },
        format="json",
    )

    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "SESSION_ENDED"


def test_session_not_found_returns_404_on_join(session_with_channels):
    client = APIClient()
    missing_id = session_with_channels["id"] + 1000
    response = client.post(
        f"/api/sessions/{missing_id}/join/",
        {
            "listener_uuid": str(uuid.uuid4()),
            "channel_id": session_with_channels["channels"][0]["id"],
        },
        format="json",
    )
    assert response.status_code == status.HTTP_404_NOT_FOUND
