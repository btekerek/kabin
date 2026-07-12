"""
Q&A floor: raise-hand queue, guide-controlled floor grant, and the
listener's publisher token once granted (see ADR-004).
"""

import uuid

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.sessions.models import RaiseHandEntry, Session

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


def _authed_client(user):
    client = APIClient()
    client.force_authenticate(user=user)
    return client


@pytest.fixture
def session_in_qa_mode(guide):
    client = _authed_client(guide)
    session = client.post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr"]},
        format="json",
    ).data
    client.post(f"/api/sessions/{session['id']}/start/")
    client.post(f"/api/sessions/{session['id']}/qa-mode/")
    return session


def _join(session_id, channel_id, listener_uuid):
    return APIClient().post(
        f"/api/sessions/{session_id}/join/",
        {"listener_uuid": listener_uuid, "channel_id": channel_id},
        format="json",
    )


def test_raise_hand_requires_qa_mode(guide):
    client = _authed_client(guide)
    session = client.post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr"]},
        format="json",
    ).data
    client.post(f"/api/sessions/{session['id']}/start/")  # active, not qa_mode

    listener_uuid = str(uuid.uuid4())
    _join(session["id"], session["channels"][0]["id"], listener_uuid)

    response = APIClient().post(
        f"/api/sessions/{session['id']}/raise-hand/",
        {"listener_uuid": listener_uuid},
        format="json",
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "NOT_IN_QA_MODE"


def test_raise_hand_requires_prior_join(session_in_qa_mode):
    response = APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": str(uuid.uuid4())},
        format="json",
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert response.data["code"] == "NOT_JOINED"


def test_raise_hand_returns_queue_position(session_in_qa_mode):
    channel_id = session_in_qa_mode["channels"][0]["id"]
    first_uuid = str(uuid.uuid4())
    second_uuid = str(uuid.uuid4())
    _join(session_in_qa_mode["id"], channel_id, first_uuid)
    _join(session_in_qa_mode["id"], channel_id, second_uuid)

    first_response = APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": first_uuid},
        format="json",
    )
    second_response = APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": second_uuid},
        format="json",
    )

    assert first_response.data["position"] == 1
    assert second_response.data["position"] == 2


def test_raise_hand_is_idempotent(session_in_qa_mode):
    channel_id = session_in_qa_mode["channels"][0]["id"]
    listener_uuid = str(uuid.uuid4())
    _join(session_in_qa_mode["id"], channel_id, listener_uuid)

    APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": listener_uuid},
        format="json",
    )
    APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": listener_uuid},
        format="json",
    )

    assert RaiseHandEntry.objects.filter(session_id=session_in_qa_mode["id"]).count() == 1


def test_lower_hand_removes_from_queue(session_in_qa_mode):
    channel_id = session_in_qa_mode["channels"][0]["id"]
    listener_uuid = str(uuid.uuid4())
    _join(session_in_qa_mode["id"], channel_id, listener_uuid)
    APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": listener_uuid},
        format="json",
    )

    response = APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/lower-hand/",
        {"listener_uuid": listener_uuid},
        format="json",
    )

    assert response.status_code == status.HTTP_204_NO_CONTENT
    assert not RaiseHandEntry.objects.filter(session_id=session_in_qa_mode["id"]).exists()


def test_lower_hand_is_a_no_op_when_not_queued(session_in_qa_mode):
    response = APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/lower-hand/",
        {"listener_uuid": str(uuid.uuid4())},
        format="json",
    )
    assert response.status_code == status.HTTP_204_NO_CONTENT


def test_guide_can_view_queue_in_order(guide, session_in_qa_mode):
    channel_id = session_in_qa_mode["channels"][0]["id"]
    first_uuid = str(uuid.uuid4())
    second_uuid = str(uuid.uuid4())
    _join(session_in_qa_mode["id"], channel_id, first_uuid)
    _join(session_in_qa_mode["id"], channel_id, second_uuid)
    APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": first_uuid},
        format="json",
    )
    APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": second_uuid},
        format="json",
    )

    response = _authed_client(guide).get(f"/api/sessions/{session_in_qa_mode['id']}/queue/")

    assert response.status_code == status.HTTP_200_OK
    assert [entry["listener_uuid"] for entry in response.data] == [first_uuid, second_uuid]


def test_non_owner_cannot_view_queue(other_guide, session_in_qa_mode):
    response = _authed_client(other_guide).get(f"/api/sessions/{session_in_qa_mode['id']}/queue/")
    assert response.status_code == status.HTTP_403_FORBIDDEN


def test_grant_floor_moves_listener_from_queue_to_approved(guide, session_in_qa_mode):
    channel_id = session_in_qa_mode["channels"][0]["id"]
    listener_uuid = str(uuid.uuid4())
    _join(session_in_qa_mode["id"], channel_id, listener_uuid)
    APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": listener_uuid},
        format="json",
    )

    response = _authed_client(guide).post(
        f"/api/sessions/{session_in_qa_mode['id']}/grant-floor/",
        {"listener_uuid": listener_uuid},
        format="json",
    )

    assert response.status_code == status.HTTP_200_OK
    session = Session.objects.get(pk=session_in_qa_mode["id"])
    assert str(session.approved_listener_uuid) == listener_uuid
    assert not RaiseHandEntry.objects.filter(session=session, listener_uuid=listener_uuid).exists()


def test_grant_floor_rejects_listener_not_in_queue(guide, session_in_qa_mode):
    response = _authed_client(guide).post(
        f"/api/sessions/{session_in_qa_mode['id']}/grant-floor/",
        {"listener_uuid": str(uuid.uuid4())},
        format="json",
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "NOT_IN_QUEUE"


def test_grant_floor_replaces_previous_floor_holder(guide, session_in_qa_mode):
    channel_id = session_in_qa_mode["channels"][0]["id"]
    first_uuid = str(uuid.uuid4())
    second_uuid = str(uuid.uuid4())
    _join(session_in_qa_mode["id"], channel_id, first_uuid)
    _join(session_in_qa_mode["id"], channel_id, second_uuid)
    for u in (first_uuid, second_uuid):
        APIClient().post(
            f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
            {"listener_uuid": u},
            format="json",
        )
    guide_client = _authed_client(guide)
    guide_client.post(
        f"/api/sessions/{session_in_qa_mode['id']}/grant-floor/",
        {"listener_uuid": first_uuid},
        format="json",
    )

    response = guide_client.post(
        f"/api/sessions/{session_in_qa_mode['id']}/grant-floor/",
        {"listener_uuid": second_uuid},
        format="json",
    )

    assert response.status_code == status.HTTP_200_OK
    session = Session.objects.get(pk=session_in_qa_mode["id"])
    assert str(session.approved_listener_uuid) == second_uuid


def test_speak_returns_token_for_approved_listener(guide, session_in_qa_mode):
    channel_id = session_in_qa_mode["channels"][0]["id"]
    listener_uuid = str(uuid.uuid4())
    _join(session_in_qa_mode["id"], channel_id, listener_uuid)
    APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": listener_uuid},
        format="json",
    )
    _authed_client(guide).post(
        f"/api/sessions/{session_in_qa_mode['id']}/grant-floor/",
        {"listener_uuid": listener_uuid},
        format="json",
    )

    response = APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/speak/",
        {"listener_uuid": listener_uuid},
        format="json",
    )

    assert response.status_code == status.HTTP_200_OK
    source_channel_id = next(c["id"] for c in session_in_qa_mode["channels"] if c["is_source"])
    assert response.data["agora_channel_name"] == f"kabin-ch-{source_channel_id}"
    assert response.data["agora_token"]


def test_speak_rejects_non_approved_listener(session_in_qa_mode):
    response = APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/speak/",
        {"listener_uuid": str(uuid.uuid4())},
        format="json",
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert response.data["code"] == "NOT_YOUR_TURN"


def test_revoke_floor_clears_approved_listener(guide, session_in_qa_mode):
    channel_id = session_in_qa_mode["channels"][0]["id"]
    listener_uuid = str(uuid.uuid4())
    _join(session_in_qa_mode["id"], channel_id, listener_uuid)
    guide_client = _authed_client(guide)
    APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": listener_uuid},
        format="json",
    )
    guide_client.post(
        f"/api/sessions/{session_in_qa_mode['id']}/grant-floor/",
        {"listener_uuid": listener_uuid},
        format="json",
    )

    response = guide_client.post(f"/api/sessions/{session_in_qa_mode['id']}/revoke-floor/")

    assert response.status_code == status.HTTP_200_OK
    session = Session.objects.get(pk=session_in_qa_mode["id"])
    assert session.approved_listener_uuid is None

    # Revoked listener can no longer get a floor token.
    speak_response = APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/speak/",
        {"listener_uuid": listener_uuid},
        format="json",
    )
    assert speak_response.status_code == status.HTTP_403_FORBIDDEN


def test_stop_clears_queue_and_floor(guide, session_in_qa_mode):
    channel_id = session_in_qa_mode["channels"][0]["id"]
    listener_uuid = str(uuid.uuid4())
    _join(session_in_qa_mode["id"], channel_id, listener_uuid)
    guide_client = _authed_client(guide)
    APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": listener_uuid},
        format="json",
    )
    guide_client.post(
        f"/api/sessions/{session_in_qa_mode['id']}/grant-floor/",
        {"listener_uuid": listener_uuid},
        format="json",
    )

    response = guide_client.post(f"/api/sessions/{session_in_qa_mode['id']}/stop/")

    assert response.status_code == status.HTTP_200_OK
    session = Session.objects.get(pk=session_in_qa_mode["id"])
    assert session.approved_listener_uuid is None
    assert not RaiseHandEntry.objects.filter(session=session).exists()


def test_raise_hand_rejects_ended_session(guide, session_in_qa_mode):
    guide_client = _authed_client(guide)
    guide_client.post(f"/api/sessions/{session_in_qa_mode['id']}/end/")

    response = APIClient().post(
        f"/api/sessions/{session_in_qa_mode['id']}/raise-hand/",
        {"listener_uuid": str(uuid.uuid4())},
        format="json",
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "SESSION_ENDED"
