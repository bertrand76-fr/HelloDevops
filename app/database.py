import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# ✅ Variable globale pour suivre si les tables ont été créées
TABLES_CREATED = False  

# ✅ Détection du mode test avec une variable d'environnement
IS_TEST = os.getenv("TEST_MODE", "0") == "1"

if IS_TEST:
    DATABASE_URL = "sqlite:///:memory:"  # ✅ SQLite pour les tests
    print("🚀 Mode TEST activé : utilisation de SQLite en mémoire")
else:
    DATABASE_URL = "postgresql://user:password@localhost:5432/mydb"  # ✅ PostgreSQL en production
    print(f"✅ Mode PRODUCTION : connexion à {DATABASE_URL}")

# ✅ Création de l'engine SQLAlchemy
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False} if IS_TEST else {})

# ✅ Création de la session SQLAlchemy
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

# ✅ Définition de la base déclarative
Base = declarative_base()



# ✅ Fonction pour récupérer une session DB
def get_db():
    global TABLES_CREATED
    db = SessionLocal()

    try:
        if IS_TEST and not TABLES_CREATED :  # ✅ Si on est en test, s'assurer que la table existe
            Base.metadata.create_all(bind=engine)
            #TABLES_CREATED = True  # ✅ Indiquer que les tables existent déjà""
                          
        yield db
    finally:
        db.close()
