from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# ✅ Configuration SQLite (en mémoire pour les tests)
DATABASE_URL_TEST = "sqlite:///:memory:"

# ✅ Création de l'engine SQLAlchemy
engine = create_engine(DATABASE_URL_TEST, connect_args={"check_same_thread": False})

# ✅ Création de la session SQLAlchemy
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

# ✅ Définition de la base déclarative
Base = declarative_base()

# ✅ Fonction pour récupérer une session DB pour les tests
def get_test_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()