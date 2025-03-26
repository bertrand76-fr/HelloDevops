#!/bin/bash

# ========== CONFIGURATION ==========
RESOURCE_GROUP="DevopsDeploymentManuelRG"
LOCATION="westus2"
ACR_NAME="monregistrydevops"
IMAGE_NAME="hellodevops"

# Génère un suffixe aléatoire de 6 caractères (compatible Bash)
SUFFIX=$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)
APP_SERVICE_PLAN="hellodevops-plan-$SUFFIX"
APP_NAME="hellodevops-$SUFFIX"

echo "🚀 Nom unique généré : $APP_NAME"

# ========== POSITIONNEMENT ==========
cd "$(dirname "$0")"
SCRIPT_DIR=$(pwd)
PROJECT_ROOT=$(realpath "$SCRIPT_DIR/..")

echo "📂 Dossier projet : $PROJECT_ROOT"

# ========== LOGIN CHECK ==========
echo "🔍 Vérification de la session Azure..."
if ! az account show > /dev/null 2>&1; then
    echo "🔐 Connexion Azure requise..."
    az login || exit 1
else
    echo "✅ Déjà connecté à Azure : $(az account show --query user.name -o tsv)"
fi

# ========== ACR ==========
echo "📦 Vérification du registre ACR..."
az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP >/dev/null 2>&1 || \
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --location $LOCATION \
  --admin-enabled true

# ========== CLOUD BUILD ==========
echo "☁️ Build de l'image Docker dans Azure..."

DOCKERFILE_PATH="$PROJECT_ROOT/Dockerfile"
if [ ! -f "$DOCKERFILE_PATH" ]; then
  echo "❌ ERREUR : Dockerfile introuvable à l'emplacement : $DOCKERFILE_PATH"
  echo "💡 Vérifie que ton script est dans le dossier 'DeploiementManuel' et que le Dockerfile est un niveau au-dessus."
  exit 1
fi

az acr build \
  --registry $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $IMAGE_NAME:latest \
  "$PROJECT_ROOT"

# ========== APP SERVICE ==========
echo "🛠️ Création du plan App Service (F1)..."
az appservice plan create \
  --name $APP_SERVICE_PLAN \
  --resource-group $RESOURCE_GROUP \
  --is-linux \
  --location $LOCATION \
  --sku F1

echo "🚀 Création de l'app web $APP_NAME..."
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_SERVICE_PLAN \
  --name $APP_NAME \
  --deployment-container-image-name $ACR_NAME.azurecr.io/$IMAGE_NAME:latest

# ========== APPLICATION INSIGHTS ==========
APPINSIGHTS_NAME="${APP_NAME}-insights"

echo "🔍 Vérification ou création d'Application Insights..."
az config set extension.use_dynamic_install=yes_without_prompt

az monitor app-insights component show \
  --app $APPINSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP >/dev/null 2>&1 || \
az monitor app-insights component create \
  --app $APPINSIGHTS_NAME \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --application-type web

echo "🔑 Récupération de la clé d'instrumentation Insights..."
INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app $APPINSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query instrumentationKey -o tsv)

echo "📎 Liaison App Service ↔ Application Insights..."
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY=$INSTRUMENTATION_KEY

# ========== CONFIGURATION ==========
echo "🔐 Récupération des identifiants ACR..."
ACR_USER=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASS=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)

echo "⚙️ Configuration du conteneur dans App Service..."
az webapp config container set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --container-image-name $ACR_NAME.azurecr.io/$IMAGE_NAME:latest \
  --container-registry-url https://$ACR_NAME.azurecr.io \
  --container-registry-user $ACR_USER \
  --container-registry-password $ACR_PASS

echo "🌍 Configuration des variables d'environnement..."
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings ENV=production

# ========== LOGS ==========
echo "📡 Activation des logs de conteneur (stdout/stderr)..."
az webapp log config \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --docker-container-logging filesystem

# ========== FIN ==========
echo "✅ Déploiement terminé avec le plan F1 sur $LOCATION"
echo "🌐 Ton app est accessible ici : https://$APP_NAME.azurewebsites.net"
