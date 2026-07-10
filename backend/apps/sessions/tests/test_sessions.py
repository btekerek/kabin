"""
Session CRUD + lifecycle tests: atomic creation with channels, ownership
enforcement, and the not_started/active/qa_mode/ended state machine
(especially that ended is a one-way door).
"""

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.sessions.models import Session

pytestmark = pytest.mark.django_db


@pytest.fixture
def guide():
    user = User(email="guide@example.com", username="guide", role=User.Role.GUIDE)
    user.set_password("password123!")
    user.save()
    return user


@pytest.fixture
def other_guide():
    user = User(email="other-guide@example.com", username="other-guide", role=User.Role.GUIDE)
    user.set_password("password123!")
    user.save()
    return user


@pytest.fixture
def interpreter():
    user = User(email="interpreter@example.com", username="interpreter", role=User.Role.INTERPRETER)
    user.set_password("password123!")
    user.save()
    return user


def _authed_client(user):
    client = APIClient()
    client.force_authenticate(user=user)
    return client


def test_guide_can_create_session_with_channels(guide):
    client = _authed_client(guide)
    response = client.post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr", "de"]},
        format="json",
    )
    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["listener_code"].isdigit()
    assert len(response.data["listener_code"]) == 6
    assert response.data["status"] == "not_started"

    channels = response.data["channels"]
    assert len(channels) == 3
    source_channels = [c for c in channels if c["is_source"]]
    assert len(source_channels) == 1
    assert source_channels[0]["language"] == "EN"
    assert source_channels[0]["interpreter_code"].startswith("EN")

    target_languages = sorted(c["language"] for c in channels if not c["is_source"])
    assert target_languages == ["DE", "TR"]


def test_session_creation_requires_at_least_one_target_language(guide):
    client = _authed_client(guide)
    response = client.post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": []},
        format="json",
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST


def test_session_creation_rejects_duplicate_target_languages(guide):
    client = _authed_client(guide)
    response = client.post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr", "TR"]},
        format="json",
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST


def test_interpreter_cannot_create_session(interpreter):
    client = _authed_client(interpreter)
    response = client.post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr"]},
        format="json",
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_list_only_returns_own_sessions(guide, other_guide):
    _authed_client(guide).post(
        "/api/sessions/",
        {"name": "Mine", "source_language": "en", "target_languages": ["tr"]},
        format="json",
    )
    _authed_client(other_guide).post(
        "/api/sessions/",
        {"name": "Theirs", "source_language": "en", "target_languages": ["tr"]},
        format="json",
    )

    response = _authed_client(guide).get("/api/sessions/")
    assert response.status_code == status.HTTP_200_OK
    names = [s["name"] for s in response.data]
    assert names == ["Mine"]


def test_non_owner_cannot_view_session_detail(guide, other_guide):
    create = _authed_client(guide).post(
        "/api/sessions/",
        {"name": "Mine", "source_language": "en", "target_languages": ["tr"]},
        format="json",
    )
    session_id = create.data["id"]

    response = _authed_client(other_guide).get(f"/api/sessions/{session_id}/")
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert response.data["code"] == "NOT_AUTHORIZED"


def _create_session(guide):
    return (
        _authed_client(guide)
        .post(
            "/api/sessions/",
            {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr"]},
            format="json",
        )
        .data
    )


def test_start_transitions_not_started_to_active(guide):
    session = _create_session(guide)
    response = _authed_client(guide).post(f"/api/sessions/{session['id']}/start/")
    assert response.status_code == status.HTTP_200_OK
    assert response.data["status"] == "active"


def test_starting_an_already_active_session_is_invalid_transition(guide):
    session = _create_session(guide)
    client = _authed_client(guide)
    client.post(f"/api/sessions/{session['id']}/start/")

    response = client.post(f"/api/sessions/{session['id']}/start/")
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "INVALID_TRANSITION"


def test_stop_returns_active_session_to_not_started(guide):
    session = _create_session(guide)
    client = _authed_client(guide)
    client.post(f"/api/sessions/{session['id']}/start/")

    response = client.post(f"/api/sessions/{session['id']}/stop/")
    assert response.status_code == status.HTTP_200_OK
    assert response.data["status"] == "not_started"


def test_ended_session_is_terminal(guide):
    session = _create_session(guide)
    client = _authed_client(guide)
    client.post(f"/api/sessions/{session['id']}/start/")

    end_response = client.post(f"/api/sessions/{session['id']}/end/")
    assert end_response.status_code == status.HTTP_200_OK
    assert end_response.data["status"] == "ended"

    reopen_attempt = client.post(f"/api/sessions/{session['id']}/start/")
    assert reopen_attempt.status_code == status.HTTP_400_BAD_REQUEST
    assert reopen_attempt.data["code"] == "SESSION_ENDED"

    assert Session.objects.get(pk=session["id"]).status == "ended"
