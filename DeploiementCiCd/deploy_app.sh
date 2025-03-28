#!/bin/bash

# Load .env existant
set -a
. ../.env
set +a


# ========== CONFIGURATION ==========
LOCATION="westus2"

# Génère un suffixe aléatoire de 6 caractères (compatible Bash)
SUFFIX=$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)
APP_SERVICE_PLAN="hellodevops-plan-$SUFFIX"
APP_NAME="hellodevops-$SUFFIX"
ACR_NAME="monregistrydevops$SUFFIX"
IMAGE_NAME="hellodevops$SUFFIX"

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

if [ -z "$INSTRUMENTATION_KEY" ]; then
  echo "❌ ERREUR : Clé d'instrumentation Application Insights non récupérée."
  exit 1
else
  echo "✅ Clé récupérée : $INSTRUMENTATION_KEY"
fi

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

echo "🔐 Activation de l'identité managée pour l'App Service..."
az webapp identity assign \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP

echo "🔎 Récupération de l'identité managée (principalId)..."
IDENTITY_PRINCIPAL_ID=$(az webapp show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query identity.principalId -o tsv)

echo "⏳ Attente que l'identité managée soit disponible dans Azure AD..."

for ((i=1; i<=10; i++)); do
  if az ad sp show --id "$IDENTITY_PRINCIPAL_ID" &>/dev/null; then
    echo "✅ Identité managée disponible dans Azure AD"
    break
  else
    echo "🔄 Tentative $i/10 : identité pas encore disponible, nouvelle tentative dans 5s..."
    sleep 5
  fi
done

if ! az ad sp show --id "$IDENTITY_PRINCIPAL_ID" &>/dev/null; then
  echo "❌ Identité managée toujours indisponible après 10 tentatives"
  exit 1
fi

#echo "🔐 Attribution des droits de lecture sur le secret à l'identité managée..."
#az keyvault set-policy \
#  --name $POSTGRES_KEYVAULT \
#  --object-id $IDENTITY_PRINCIPAL_ID \
#  --secret-permissions get list

# 📋 Récupération du contexte Azure
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "🔐 Attribution des droits RBAC 'Key Vault Secrets User' à l'identité managée..."

powershell.exe -Command "
  \$assignee = '$IDENTITY_PRINCIPAL_ID'
  \$scope = '/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$POSTGRES_KEYVAULT'
  az role assignment create --assignee \$assignee --role 'Key Vault Secrets User' --scope \$scope
"

if [ $? -ne 0 ]; then
  echo "❌ Échec de l'attribution du rôle RBAC à l'identité managée"
  exit 1
fi

echo "✅ L'identité managée peut accéder au secret POSTGRES-PASSWORD dans $POSTGRES_KEYVAULT"


echo "🌍 Configuration des variables d'environnement (avec référence au secret Key Vault)..."
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    ENV=production \
    APPINSIGHTS_INSTRUMENTATIONKEY=$INSTRUMENTATION_KEY \
    POSTGRES_USER=$POSTGRES_USER \
    POSTGRES_SERVER=$POSTGRES_SERVER \
    POSTGRES_PASSWORD="@Microsoft.KeyVault(SecretUri=https://$POSTGRES_KEYVAULT.vault.azure.net/secrets/POSTGRES-PASSWORD/)"

# ========== LOGS ==========
echo "📡 Activation des logs de conteneur (stdout/stderr)..."
az webapp log config \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --docker-container-logging filesystem

# ========== FIN ==========
echo "✅ Déploiement terminé avec le plan F1 sur $LOCATION"
echo "🌐 Ton app est accessible ici : https://$APP_NAME.azurewebsites.net"
