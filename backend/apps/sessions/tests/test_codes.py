"""
Direct tests of the retry-on-collision code generators - this is the one
requirement called out explicitly in the project spec ("retry code
generation on collision"), so it gets its own focused test rather than
being inferred from the higher-level session-creation tests.
"""

import pytest

from apps.accounts.models import User
from apps.sessions import codes
from apps.sessions.models import Channel, Session

pytestmark = pytest.mark.django_db


@pytest.fixture
def guide():
    user = User(email="guide@example.com", username="guide", role=User.Role.GUIDE)
    user.set_password("correct-horse-battery-staple")
    user.save()
    return user


def test_generate_listener_code_is_a_plain_six_digit_pin(guide):
    code = codes.generate_listener_code()
    assert len(code) == 6
    assert code.isdigit()


def test_generate_listener_code_retries_on_collision(monkeypatch, guide):
    Session.objects.create(
        owner=guide, name="Existing", source_language="EN", listener_code="000000"
    )
    attempts = iter(["000000", "111111"])
    monkeypatch.setattr(codes, "_random_digits", lambda n: next(attempts))

    code = codes.generate_listener_code()

    assert code == "111111"


def test_generate_interpreter_code_retries_on_collision(monkeypatch, guide):
    session = Session.objects.create(
        owner=guide, name="Existing", source_language="EN", listener_code="999999"
    )
    Channel.objects.create(
        session=session, language="EN", interpreter_code="EN000000", is_source=True
    )
    attempts = iter(["000000", "222222"])
    monkeypatch.setattr(codes, "_random_digits", lambda n: next(attempts))

    code = codes.generate_interpreter_code("EN")

    assert code == "EN222222"


def test_generate_listener_code_gives_up_after_max_attempts(monkeypatch, guide):
    Session.objects.create(
        owner=guide, name="Existing", source_language="EN", listener_code="000000"
    )
    monkeypatch.setattr(codes, "_random_digits", lambda n: "000000")

    with pytest.raises(codes.CodeGenerationError):
        codes.generate_listener_code()
