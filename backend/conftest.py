import pytest


@pytest.fixture(autouse=True)
def _enable_db_access_for_all_tests(db):
    """Every test gets DB access by default; opt out per-test if needed."""
    pass
