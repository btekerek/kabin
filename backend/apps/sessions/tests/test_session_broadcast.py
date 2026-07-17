"""
Guide source-channel broadcast token: lets the session owner get a
publisher token for their own source channel, independent of session
status - see SessionBroadcastView docstring for why mic on/off isn't
tied to start/stop/end.
"""

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User

pytestmark = pytest.mark.django_db


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
def unrelated_user():
    user = User(email="unrelated-user@example.com", username="unrelated-user")
    user.set_password("password123!")
    user.save()
    return user


def _authed_client(user):
    client = APIClient()
    client.force_authenticate(user=user)
    return client


@pytest.fixture
def session(guide):
    response = _authed_client(guide).post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr"]},
        format="json",
    )
    return response.data


def test_guide_can_get_broadcast_token_for_own_session(guide, session):
    source_channel = session["channels"][0]
    response = _authed_client(guide).post(f"/api/sessions/{session['id']}/broadcast/")

    assert response.status_code == status.HTTP_200_OK
    assert response.data["agora_channel_name"] == f"kabin-ch-{source_channel['id']}"
    assert response.data["agora_token"]
    assert response.data["channel"]["is_source"] is True
    # Full ChannelSerializer (their own channel) - interpreter_code intact.
    assert response.data["channel"]["interpreter_code"] == source_channel["interpreter_code"]


def test_broadcast_token_available_before_session_starts(guide, session):
    # Mic on/off is independent of session status - a Guide can test their
    # mic (or just go live) any time before the session ends.
    response = _authed_client(guide).post(f"/api/sessions/{session['id']}/broadcast/")
    assert response.status_code == status.HTTP_200_OK


def test_broadcast_token_available_while_active(guide, session):
    client = _authed_client(guide)
    client.post(f"/api/sessions/{session['id']}/start/")

    response = client.post(f"/api/sessions/{session['id']}/broadcast/")
    assert response.status_code == status.HTTP_200_OK


def test_broadcast_rejected_after_session_ended(guide, session):
    client = _authed_client(guide)
    client.post(f"/api/sessions/{session['id']}/start/")
    client.post(f"/api/sessions/{session['id']}/end/")

    response = client.post(f"/api/sessions/{session['id']}/broadcast/")
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "SESSION_ENDED"


def test_non_owner_guide_cannot_broadcast(other_guide, session):
    response = _authed_client(other_guide).post(f"/api/sessions/{session['id']}/broadcast/")
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_unrelated_user_cannot_broadcast_to_session(unrelated_user, session):
    response = _authed_client(unrelated_user).post(f"/api/sessions/{session['id']}/broadcast/")
    assert response.status_code == status.HTTP_403_FORBIDDEN
