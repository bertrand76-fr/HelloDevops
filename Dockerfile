# Utilise une image officielle Python
FROM python:3.10-slim

# Crée un dossier pour l'app
WORKDIR /app

# Copie les fichiers
COPY ./app /app/app
COPY requirements.txt /app
COPY .env /app

# Installe les dépendances
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

# Expose le port de l'app
EXPOSE 80

# Commande de démarrage de FastAPI avec Uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "80"]
