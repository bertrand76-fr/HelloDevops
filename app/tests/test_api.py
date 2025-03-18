# Activer le mode test (avant d'importer la base)
import os
#os.environ["TEST_MODE"] = "1"

import pytest
#from app.tests.test_api import test_db
from fastapi.testclient import TestClient
from app.main import app
from sqlalchemy import text
from app.databastest import Base, engine, get_test_db, SessionLocal

from app.models import Message


# ✅ Créer les tables au début des tests
print("📌 Création des tables en mémoire...")
Base.metadata.create_all(bind=engine)
print("✅ Tables SQLite créées :", Base.metadata.tables.keys())

# Client de test FastAPI
client = TestClient(app)



# Fournir une session de test à la place de PostgreSQL
@pytest.fixture(scope="function")
def test_db():
    # Utiliser une base SQLite en mémoire pour les tests
    print("🛠️ Création des tables en mémoire...")
    print("📌 Tables détectées par SQLAlchemy :", Base.metadata.tables.keys())
    Base.metadata.create_all(bind=engine)
    print("✅ Tables créées !")
    print("📌 Tables détectées par SQLAlchemy :", Base.metadata.tables.keys())

    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

""""
def test_database_ready(test_db):
    result = test_db.execute(text("SELECT name FROM sqlite_master WHERE type='table' AND name='messages';")).fetchone()
    assert result is not None, "❌ La table 'messages' n'a pas été créée !"
"""

# Tester POST /store
def test_store_message(test_db):
    response = client.post("/store", json={"content": "Test Message"})
    assert response.status_code == 200
    data = response.json()
    assert "id" in data
    assert data["message"] == "Stored successfully"

# Tester GET /getAll
def test_get_all_messages(test_db):
    response = client.get("/getAll")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

# Tester GET /getById/{id}
def test_get_by_id(test_db):
    post_response = client.post("/store", json={"content": "Hello Test"})
    message_id = post_response.json()["id"]

    get_response = client.get(f"/getById/{message_id}")
    assert get_response.status_code == 200
    assert get_response.json()["content"] == "Hello Test"

# Tester DELETE /deleteById/{id}
def test_delete_by_id(test_db):
    post_response = client.post("/store", json={"content": "To Delete"})
    message_id = post_response.json()["id"]

    delete_response = client.delete(f"/deleteById/{message_id}")
    assert delete_response.status_code == 200
    assert delete_response.json()["message"] == f"Message with id {message_id} deleted successfully"

    # Vérifier que le message a bien été supprimé
    get_response = client.get(f"/getById/{message_id}")
    assert get_response.status_code == 404

