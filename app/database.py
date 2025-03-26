import os
import time
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker
import subprocess

# ✅ Variable globale pour suivre si les tables ont été créées
TABLES_CREATED = False  

# ✅ Détection du mode test avec une variable d'environnement
IS_TEST = os.getenv("TEST_MODE", "0") == "1"

if IS_TEST:
    DATABASE_URL = "sqlite:///:memory:"  # ✅ SQLite pour les tests
    print("🚀 Mode TEST activé : utilisation de SQLite en mémoire")
else:
    # ✅ Connexion à PostgreSQL Azure
    POSTGRES_USER = os.getenv("POSTGRES_USER", "devopsadmin")
    POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "devopsadmin")
    POSTGRES_SERVER = os.getenv("POSTGRES_SERVER", "hellodevops-db-postgres")
    POSTGRES_SERVER_SUFFIX = os.getenv("POSTGRES_SERVER_SUFFIX", ".postgres.database.azure.com")
    POSTGRES_DB = os.getenv("POSTGRES_DB", "postgres")
    RESOURCE_GROUP = os.getenv("AZURE_RESOURCE_GROUP", "DevopsDeploymentManuelRG")

    DATABASE_URL = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_SERVER}{POSTGRES_SERVER_SUFFIX}:5432/{POSTGRES_DB}?sslmode=require"
    print(f"✅ Mode PRODUCTION : connexion à {POSTGRES_SERVER}{POSTGRES_SERVER_SUFFIX}")

    # DATABASE_URL = "postgresql://user:password@localhost:5432/mydb"  # ✅ PostgreSQL en production
    # print(f"✅ Mode PRODUCTION : connexion à {DATABASE_URL}")

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

# ✅ Fonction pour redémarrer PostgreSQL Azure
def restart_postgres():
    print("🔄 Tentative de redémarrage du serveur PostgreSQL via Azure CLI...")
    restart_command = f"az postgres flexible-server start --name {POSTGRES_SERVER} --resource-group {RESOURCE_GROUP}"
    
    try:
        subprocess.run(restart_command, shell=True, check=True)
        print("✅ Serveur PostgreSQL redémarré avec succès !")
        time.sleep(20)  # ⏳ Attendre 20 secondes que le serveur redémarre complètement
    except Exception as e:
        print(f"❌ Échec du redémarrage de PostgreSQL : {e}")


"""
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
"""
# ✅ Fonction pour récupérer une session DB avec support de test
def get_db():
    global TABLES_CREATED
    db = None
    if IS_TEST:  # 🚀 En test, s'assurer que la table existe
        db = SessionLocal()
    else:

        max_retries = 3  # 🔄 Nombre maximum de tentatives de reconnexion
        attempt = 0

        while attempt < max_retries:
            if is_postgres_running():
                db = SessionLocal()
                break
            else:
                print(f"⚠️ PostgreSQL est inactif. Tentative de redémarrage ({attempt + 1}/{max_retries})...")
                restart_postgres()
                time.sleep(10)  # ⏳ Attendre avant de réessayer
                attempt += 1

        if db is None:
            raise Exception("❌ Impossible de se connecter à PostgreSQL après plusieurs tentatives.")

    try:
        if IS_TEST:  # 🚀 En test, s'assurer que la table existe
            Base.metadata.create_all(bind=engine)
                          
        yield db
    finally:
        db.close()