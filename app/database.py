from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker


# Configuration de la connexion PostgreSQL
DATABASE_URL = "postgresql://user:password@localhost:5432/mydb"

# Création de l'engine SQLAlchemy
engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()


# Dépendance pour injecter la session de base de données
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()