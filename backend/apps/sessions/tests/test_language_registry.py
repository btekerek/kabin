"""
Language registry (see ADR-006): session creation only accepts real
ISO 639-1 language codes, and the public /api/languages/ endpoint
exposes the same registry clients validate against.
"""

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User


@pytest.fixture
def guide(db):
    user = User(email="guide@example.com", username="guide")
    user.set_password("password123!")
    user.save()
    return user


def _authed_client(user):
    client = APIClient()
    client.force_authenticate(user=user)
    return client


def test_session_creation_rejects_unsupported_source_language(guide):
    response = _authed_client(guide).post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "asdf", "target_languages": ["tr"]},
        format="json",
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "UNSUPPORTED_LANGUAGE"


def test_session_creation_rejects_unsupported_target_language(guide):
    response = _authed_client(guide).post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": ["asdf"]},
        format="json",
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "UNSUPPORTED_LANGUAGE"


def test_session_creation_accepts_real_languages_case_insensitively(guide):
    response = _authed_client(guide).post(
        "/api/sessions/",
        {"name": "Kabin Conf", "source_language": "en", "target_languages": ["tr", "de", "ja"]},
        format="json",
    )
    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["source_language"] == "EN"
    languages = {channel["language"] for channel in response.data["channels"]}
    assert languages == {"EN", "TR", "DE", "JA"}


def test_language_list_endpoint_returns_full_registry(db):
    response = APIClient().get("/api/languages/")
    assert response.status_code == status.HTTP_200_OK
    assert len(response.data) > 150
    codes = {entry["code"] for entry in response.data}
    assert "EN" in codes
    assert "TR" in codes
    names = {entry["code"]: entry["name"] for entry in response.data}
    assert names["EN"] == "English"
    assert names["TR"] == "Turkish"


def test_language_list_endpoint_requires_no_auth(db):
    response = APIClient().get("/api/languages/")
    assert response.status_code == status.HTTP_200_OK
