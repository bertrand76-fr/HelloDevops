# 1. Créer le dossier du projet
mkdir HelloDevOps
cd HelloDevOps

# 2. Créer l'environnement virtuel
python -m venv env

# 3. Activer l'environnement virtuel
# Windows (PowerShell)
# env\Scripts\activate
# Mac/Linux
source env/bin/activate

# 4. Installer les dépendances de base
pip install fastapi uvicorn psycopg2 azure-servicebus pytest

# 5. Créer les dossiers du projet
mkdir app
mkdir app\routes
mkdir app\tests
mkdir terraform
mkdir .github
mkdir .github\workflows

# 6. Créer les fichiers de base
type nul > app\__init__.py
type nul > app\main.py
type nul > app\database.py
type nul > app\models.py
type nul > app\schemas.py
type nul > app\service_bus.py

type nul > app\routes\__init__.py
type nul > app\routes\messages.py

type nul > app\tests\__init__.py
type nul > app\tests\test_api.py

type nul > terraform\main.tf
type nul > .github\workflows\deploy.yml
type nul > requirements.txt
type nul > docker-compose.yml
type nul > README.md
#touch app/__init__.py app/main.py app/database.py app/models.py app/schemas.py

touch app/service_bus.py app/routes/__init__.py app/routes/messages.py

touch app/tests/__init__.py app/tests/test_api.py

touch docker-compose.yml requirements.txt README.md

touch .github/workflows/deploy.yml

touch terraform/main.tf

# 7. Ajouter du code de base
echo "from fastapi import FastAPI" > app/main.py
echo "\napp = FastAPI()" >> app/main.py
echo "\n@app.get('/')" >> app/main.py
echo "def read_root():" >> app/main.py
echo "    return {'message': 'Hello, DevOps!'}" >> app/main.py

# 8. Enregistrer les dépendances
pip freeze > requirements.txt

# 9. Afficher la structure du projet
tree
