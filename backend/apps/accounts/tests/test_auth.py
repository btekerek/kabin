"""
Auth endpoint tests: register, login, refresh rotation, logout blacklist.

The refresh-rotation test is the one that matters most: it proves a used
refresh token cannot be reused, which is the whole point of ADR-001.
"""

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.models import User

pytestmark = pytest.mark.django_db


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def guide_user():
    user = User(email="guide@example.com", username="guide", role=User.Role.GUIDE)
    user.set_password("correct-horse-battery-staple")
    user.save()
    return user


def test_register_creates_user_with_role(api_client):
    response = api_client.post(
        "/api/auth/register/",
        {
            "email": "new-guide@example.com",
            "password": "correct-horse-battery-staple",
            "role": "guide",
        },
    )
    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["email"] == "new-guide@example.com"
    assert response.data["role"] == "guide"
    assert User.objects.filter(email="new-guide@example.com").exists()


def test_register_duplicate_email_returns_email_in_use(api_client, guide_user):
    response = api_client.post(
        "/api/auth/register/",
        {"email": guide_user.email, "password": "another-password-1", "role": "guide"},
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "EMAIL_IN_USE"


def test_register_missing_role_returns_missing_fields(api_client):
    response = api_client.post(
        "/api/auth/register/",
        {"email": "no-role@example.com", "password": "correct-horse-battery-staple"},
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "MISSING_FIELDS"


def test_login_with_correct_credentials_returns_token_pair(api_client, guide_user):
    response = api_client.post(
        "/api/auth/login/",
        {"email": guide_user.email, "password": "correct-horse-battery-staple"},
    )
    assert response.status_code == status.HTTP_200_OK
    assert "access" in response.data
    assert "refresh" in response.data


def test_login_with_wrong_password_returns_invalid_credentials(api_client, guide_user):
    response = api_client.post(
        "/api/auth/login/",
        {"email": guide_user.email, "password": "wrong-password"},
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert response.data["code"] == "INVALID_CREDENTIALS"


def test_login_unknown_email_returns_invalid_credentials(api_client):
    response = api_client.post(
        "/api/auth/login/",
        {"email": "nobody@example.com", "password": "whatever-it-is"},
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert response.data["code"] == "INVALID_CREDENTIALS"


def test_refresh_rotates_token_and_blacklists_the_old_one(api_client, guide_user):
    login = api_client.post(
        "/api/auth/login/",
        {"email": guide_user.email, "password": "correct-horse-battery-staple"},
    )
    old_refresh = login.data["refresh"]

    first_refresh = api_client.post("/api/auth/refresh/", {"refresh": old_refresh})
    assert first_refresh.status_code == status.HTTP_200_OK
    new_refresh = first_refresh.data["refresh"]
    assert new_refresh != old_refresh

    # Reusing the old (now-rotated) refresh token must fail: this is the
    # compromise-detection tripwire from ADR-001.
    reuse_attempt = api_client.post("/api/auth/refresh/", {"refresh": old_refresh})
    assert reuse_attempt.status_code == status.HTTP_401_UNAUTHORIZED

    # The new refresh token, however, still works.
    second_refresh = api_client.post("/api/auth/refresh/", {"refresh": new_refresh})
    assert second_refresh.status_code == status.HTTP_200_OK


def test_me_requires_authentication(api_client):
    response = api_client.get("/api/auth/me/")
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


def test_me_returns_current_user(api_client, guide_user):
    login = api_client.post(
        "/api/auth/login/",
        {"email": guide_user.email, "password": "correct-horse-battery-staple"},
    )
    access = login.data["access"]
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    response = api_client.get("/api/auth/me/")
    assert response.status_code == status.HTTP_200_OK
    assert response.data["email"] == guide_user.email
    assert response.data["role"] == "guide"


def test_logout_blacklists_refresh_token(api_client, guide_user):
    login = api_client.post(
        "/api/auth/login/",
        {"email": guide_user.email, "password": "correct-horse-battery-staple"},
    )
    access = login.data["access"]
    refresh = login.data["refresh"]

    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    logout = api_client.post("/api/auth/logout/", {"refresh": refresh})
    assert logout.status_code == status.HTTP_205_RESET_CONTENT

    reuse_attempt = api_client.post("/api/auth/refresh/", {"refresh": refresh})
    assert reuse_attempt.status_code == status.HTTP_401_UNAUTHORIZED
