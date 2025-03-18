# Activer le mode test (avant d'importer la base)
import os
os.environ["TEST_MODE"] = "1"

import pytest
#from app.tests.test_api import test_db
from fastapi.testclient import TestClient
from app.main import app
from sqlalchemy import text
from app.database import Base, engine, SessionLocal

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
    db = SessionLocal()   
    try:
        yield db
    finally:
        db.close()

        
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
    testGetId = "testGetId"
    get_response = client.get(f"/getById/{testGetId}")
    assert testGetId in str(get_response.json()) 



# Tester DELETE /deleteById/{id}
def test_delete_by_id(test_db):
    testDeleteId = "testDeleteId"
    delete_response = client.delete(f"/deleteById/{testDeleteId}")
    assert testDeleteId in str(delete_response.json()) 

