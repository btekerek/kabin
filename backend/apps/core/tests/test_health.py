from django.urls import reverse
from rest_framework.test import APIClient


def test_health_check_ok():
    client = APIClient()
    response = client.get(reverse("health-check"))
    assert response.status_code == 200
    assert response.data["status"] == "ok"
