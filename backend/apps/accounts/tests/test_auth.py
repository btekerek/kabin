"""
Auth endpoint tests: register, login (by email or username), refresh
rotation, logout blacklist.

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
    user = User(email="guide@example.com", username="guide")
    user.set_password("correct-horse-battery-staple")
    user.save()
    return user


def test_register_creates_user(api_client):
    response = api_client.post(
        "/api/auth/register/",
        {
            "email": "new-user@example.com",
            "password": "correct-horse-battery-staple",
            "username": "nova",
        },
    )
    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["email"] == "new-user@example.com"
    assert response.data["username"] == "nova"
    assert User.objects.filter(email="new-user@example.com").exists()


def test_register_duplicate_email_returns_email_in_use(api_client, guide_user):
    response = api_client.post(
        "/api/auth/register/",
        {"email": guide_user.email, "password": "another-password-1", "username": "someone-else"},
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "EMAIL_IN_USE"


def test_register_duplicate_username_returns_username_in_use(api_client, guide_user):
    response = api_client.post(
        "/api/auth/register/",
        {
            "email": "someone-else@example.com",
            "password": "another-password-1",
            "username": guide_user.username,
        },
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "USERNAME_IN_USE"


def test_register_missing_password_returns_missing_fields(api_client):
    response = api_client.post(
        "/api/auth/register/",
        {"email": "no-password@example.com", "username": "nova"},
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "MISSING_FIELDS"


def test_register_without_username_generates_one_from_email(api_client):
    response = api_client.post(
        "/api/auth/register/",
        {"email": "nameless@example.com", "password": "correct-horse-battery-staple"},
    )
    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["username"] == "nameless"


def test_register_without_username_dedupes_generated_name(api_client, guide_user):
    # guide_user's email local part is "guide" - same as its username, so
    # a second account whose email also starts with "guide@" needs a
    # distinct generated username rather than colliding with it.
    response = api_client.post(
        "/api/auth/register/",
        {"email": "guide@other-example.com", "password": "correct-horse-battery-staple"},
    )
    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["username"] == "guide2"


def test_register_blank_username_generates_one_from_email(api_client):
    response = api_client.post(
        "/api/auth/register/",
        {
            "email": "blank-username@example.com",
            "password": "correct-horse-battery-staple",
            "username": "   ",
        },
    )
    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["username"] == "blank-username"


def test_login_with_email_returns_token_pair(api_client, guide_user):
    response = api_client.post(
        "/api/auth/login/",
        {"identifier": guide_user.email, "password": "correct-horse-battery-staple"},
    )
    assert response.status_code == status.HTTP_200_OK
    assert "access" in response.data
    assert "refresh" in response.data


def test_login_with_username_returns_token_pair(api_client, guide_user):
    response = api_client.post(
        "/api/auth/login/",
        {"identifier": guide_user.username, "password": "correct-horse-battery-staple"},
    )
    assert response.status_code == status.HTTP_200_OK
    assert "access" in response.data
    assert "refresh" in response.data


def test_login_with_wrong_password_returns_invalid_credentials(api_client, guide_user):
    response = api_client.post(
        "/api/auth/login/",
        {"identifier": guide_user.email, "password": "wrong-password"},
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert response.data["code"] == "INVALID_CREDENTIALS"


def test_login_unknown_identifier_returns_invalid_credentials(api_client):
    response = api_client.post(
        "/api/auth/login/",
        {"identifier": "nobody@example.com", "password": "whatever-it-is"},
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert response.data["code"] == "INVALID_CREDENTIALS"


def test_refresh_rotates_token_and_blacklists_the_old_one(api_client, guide_user):
    login = api_client.post(
        "/api/auth/login/",
        {"identifier": guide_user.email, "password": "correct-horse-battery-staple"},
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
        {"identifier": guide_user.email, "password": "correct-horse-battery-staple"},
    )
    access = login.data["access"]
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    response = api_client.get("/api/auth/me/")
    assert response.status_code == status.HTTP_200_OK
    assert response.data["email"] == guide_user.email
    assert response.data["username"] == guide_user.username


def test_logout_blacklists_refresh_token(api_client, guide_user):
    login = api_client.post(
        "/api/auth/login/",
        {"identifier": guide_user.email, "password": "correct-horse-battery-staple"},
    )
    access = login.data["access"]
    refresh = login.data["refresh"]

    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    logout = api_client.post("/api/auth/logout/", {"refresh": refresh})
    assert logout.status_code == status.HTTP_205_RESET_CONTENT

    reuse_attempt = api_client.post("/api/auth/refresh/", {"refresh": refresh})
    assert reuse_attempt.status_code == status.HTTP_401_UNAUTHORIZED


def test_login_with_generated_username_works(api_client):
    api_client.post(
        "/api/auth/register/",
        {"email": "autogen@example.com", "password": "correct-horse-battery-staple"},
    )
    response = api_client.post(
        "/api/auth/login/",
        {"identifier": "autogen", "password": "correct-horse-battery-staple"},
    )
    assert response.status_code == status.HTTP_200_OK


def test_update_username_requires_authentication(api_client):
    response = api_client.patch("/api/auth/me/", {"username": "new-name"})
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


def test_update_username_changes_it_and_can_then_log_in_with_it(api_client, guide_user):
    login = api_client.post(
        "/api/auth/login/",
        {"identifier": guide_user.email, "password": "correct-horse-battery-staple"},
    )
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")

    response = api_client.patch("/api/auth/me/", {"username": "guide-renamed"}, format="json")
    assert response.status_code == status.HTTP_200_OK
    assert response.data["username"] == "guide-renamed"

    relogin = APIClient().post(
        "/api/auth/login/",
        {"identifier": "guide-renamed", "password": "correct-horse-battery-staple"},
    )
    assert relogin.status_code == status.HTTP_200_OK


def test_update_username_rejects_duplicate(api_client, guide_user):
    other = User(email="other@example.com", username="other-guide")
    other.set_password("password123!")
    other.save()

    login = api_client.post(
        "/api/auth/login/",
        {"identifier": guide_user.email, "password": "correct-horse-battery-staple"},
    )
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")

    response = api_client.patch("/api/auth/me/", {"username": "other-guide"}, format="json")
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "USERNAME_IN_USE"


def test_update_username_rejects_blank(api_client, guide_user):
    login = api_client.post(
        "/api/auth/login/",
        {"identifier": guide_user.email, "password": "correct-horse-battery-staple"},
    )
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")

    response = api_client.patch("/api/auth/me/", {"username": "   "}, format="json")
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["code"] == "MISSING_FIELDS"
