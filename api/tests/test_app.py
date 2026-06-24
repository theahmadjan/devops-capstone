import pytest
import sys
import os

# Make sure Python can find the api folder
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../.."))

from unittest.mock import patch, MagicMock

# This fixture creates a test client with MongoDB mocked out
# so tests run without needing a real database
@pytest.fixture
def client():
    with patch("api.app.MongoClient") as mock_client:
        mock_db = MagicMock()
        mock_client.return_value.__getitem__.return_value = mock_db
        mock_db.__getitem__.return_value = MagicMock()
        from api.app import app
        app.config["TESTING"] = True
        with app.test_client() as c:
            yield c

def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"

def test_add_item_missing_name(client):
    response = client.post("/api/items",
        json={},
        content_type="application/json")
    assert response.status_code == 400
