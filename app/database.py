from dotenv import load_dotenv
load_dotenv()
import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker

# ✅ Variable globale pour suivre si les tables ont été créées
TABLES_CREATED = False  

# ✅ Détection du mode test avec une variable d'environnement
IS_TEST = os.getenv("TEST_MODE", "0") == "1"

if IS_TEST:
    DATABASE_URL = "sqlite:///:memory:"  # ✅ SQLite pour les tests
    print("🚀 Mode TEST activé : utilisation de SQLite en mémoire")
else:
    # ✅ Connexion à PostgreSQL Azure
    try:
        POSTGRES_USER = os.getenv("POSTGRES_USER")
        POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")
        POSTGRES_SERVER = os.getenv("POSTGRES_SERVER")

        DATABASE_URL = (
            f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}"
            f"@{POSTGRES_SERVER}.postgres.database.azure.com:5432/postgres?sslmode=require"
        )
        print(f"✅ Mode PRODUCTION : connexion via DATABASE_URL")
    except KeyError:
        raise RuntimeError("❌ DATABASE_URL non défini dans les variables d'environnement")

# ✅ Création de l'engine SQLAlchemy
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False} if IS_TEST else {})

# ✅ Création de la session SQLAlchemy
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

# ✅ Définition de la base déclarative
Base = declarative_base()

# ✅ Fonction pour vérifier si PostgreSQL est en ligne
def is_postgres_running():
    try:
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            return result.fetchone() is not None
    except Exception as e:
        print(f"⚠️ Erreur de connexion à PostgreSQL : {e}")
        return False

# ✅ Fonction pour récupérer une session DB avec support de test
def get_db():
    db = SessionLocal()
    try:
        if IS_TEST:  # 🚀 En test, s'assurer que la table existe
            Base.metadata.create_all(bind=engine)                          
        yield db
    finally:
        db.close()