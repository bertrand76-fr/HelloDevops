#!/bin/bash

if ! az account show >/dev/null 2>&1; then
  echo "❌ Vous n'êtes pas connecté à Azure. Exécutez 'az login' d'abord."
  exit 1
fi

# Load .env existant
set -a
. ../.env
set +a

# Creation de nom de base et de keyvault unique
SUFFIX=$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)
POSTGRES_SERVER="${POSTGRES_SERVER_BASE_NAME}-${SUFFIX}"
POSTGRES_KEYVAULT="${POSTGRES_KEYVAULT_BASE_NAME}-${SUFFIX}"

sed -i "/^POSTGRES_SERVER=/d" ../.env
echo "POSTGRES_SERVER=$POSTGRES_SERVER" >> ../.env

echo "🚀 Ajout de  POSTGRES_SERVER=$POSTGRES_SERVER dans .env"

sed -i "/^POSTGRES_KEYVAULT=/d" ../.env
echo "POSTGRES_KEYVAULT=$POSTGRES_KEYVAULT" >> ../.env

echo "🚀 Ajout de  POSTGRES_KEYVAULT=$POSTGRES_KEYVAULT dans .env"

# 🔹 Configuration des variables specifiques a la creation de la base
LOCATION="westus2"  # ✅ Région Hawaï
MY_IP_ADDRESS=$(curl -s https://api.ipify.org)

echo "🚀 Déploiement de PostgreSQL Flexible Server en mode Spot sur Azure (Hawaï)..."

# 🔹 Vérifier si le Resource Group existe, sinon le créer
az group show --name $RESOURCE_GROUP &>/dev/null
if [ $? -ne 0 ]; then
    echo "📌 Création du Resource Group $RESOURCE_GROUP..."
    az group create --name $RESOURCE_GROUP --location "$LOCATION"
fi

# 🔐 Création du Key Vault
az keyvault create \
  --name $POSTGRES_KEYVAULT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --only-show-errors >/dev/null

echo "🔐 Key Vault $POSTGRES_KEYVAULT créé, en attente de disponibilité..."

# ✅ Attente que le Key Vault soit prêt
MAX_ATTEMPTS=10
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  STATUS=$(az keyvault show --name $POSTGRES_KEYVAULT --query properties.provisioningState -o tsv 2>/dev/null)
  if [ "$STATUS" == "Succeeded" ]; then
    echo "✅ Key Vault provisionné avec succès"
    break
  else
    echo "⏳ Tentative $i : état = $STATUS, nouvelle tentative dans 2s..."
    sleep 2
  fi
done

if [ "$STATUS" != "Succeeded" ]; then
  echo "❌ Le Key Vault n'est pas prêt après $MAX_ATTEMPTS tentatives"
  exit 1
fi

# 📋 Récupération du contexte
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SIGNED_IN_USER_ID=$(az ad signed-in-user show --query id -o tsv)
KEYVAULT_ID=$(az keyvault show --name $POSTGRES_KEYVAULT --query id -o tsv)

echo "🔎 Subscription ID : $SUBSCRIPTION_ID"
echo "🔎 User ID        : $SIGNED_IN_USER_ID"
echo "🔎 Key Vault ID   : $KEYVAULT_ID"

# ⏳ Stabilisation de l’environnement Azure
echo "🧘‍♂️ Attente pour stabilisation du contexte Azure..."
sleep 10

# ✅ Forcer l’abonnement actif pour éviter les erreurs "MissingSubscription"
az account set --subscription "$SUBSCRIPTION_ID"
echo "📌 Abonnement forcé sur $SUBSCRIPTION_ID"


# 🛡️ Attribution du rôle Key Vault Administrator
echo "🛡️ Attribution du rôle 'Key Vault Administrator' à l'utilisateur via PowerShell..."

powershell.exe -Command "
    \$assignee = '$SIGNED_IN_USER_ID'
    \$scope = '$KEYVAULT_ID'
    \$subscription = '$SUBSCRIPTION_ID'
    az account set --subscription \$subscription
    az role assignment create --assignee \$assignee --role 'Key Vault Administrator' --scope \$scope --subscription \$subscription
"
if [ $? -ne 0 ]; then
  echo "❌ Échec de l'attribution du rôle dans PowerShell."
  echo "ℹ️  Vérifie manuellement avec la commande suivante :"
  echo "   az role assignment create --assignee $SIGNED_IN_USER_ID --role 'Key Vault Administrator' --scope $KEYVAULT_ID --subscription $SUBSCRIPTION_ID"
  exit 1
fi

echo "✅ Rôle attribué à l'utilisateur pour $POSTGRES_KEYVAULT"


# 🔄 Vérification que le rôle est bien actif
echo "🕒 Attente de 30s pour propagation RBAC..."
sleep 30

echo "⏳ Vérification que l'accès Key Vault est bien effectif..."
for ((i=1; i<=30; i++)); do
  if az keyvault secret list --vault-name "$POSTGRES_KEYVAULT" >/dev/null 2>&1; then
    echo "✅ Accès au Key Vault validé ✅"
    break
  else
    echo "🔄 Tentative $i/30 : accès non encore effectif, nouvelle tentative dans 10s..."
    sleep 10
  fi
done

if [ $i -gt 30 ]; then
  echo "❌ Échec : L'accès Key Vault n'est pas effectif après 5 minutes"
  exit 1
fi

# 🔑 Génération du mot de passe
POSTGRES_PASSWORD=$(openssl rand -base64 16)
echo "🔑 Mot de passe sécurisé généré"

# 🔐 Stockage dans Key Vault
az keyvault secret set \
  --vault-name "$POSTGRES_KEYVAULT" \
  --name POSTGRES-PASSWORD \
  --value "$POSTGRES_PASSWORD" >/dev/null

echo "🔐 Secret POSTGRES-PASSWORD enregistré dans $POSTGRES_KEYVAULT"

# 🔹 Création du serveur PostgreSQL Flexible en mode Spot (Hawaï)
az postgres flexible-server create \
    --resource-group $RESOURCE_GROUP \
    --name $POSTGRES_SERVER \
    --location "$LOCATION" \
    --sku-name Standard_B1ms \
    --tier Burstable \
    --high-availability Disabled \
    --public-access Enabled \
    --admin-user $POSTGRES_USER \
    --admin-password "$POSTGRES_PASSWORD"

echo "✅ Base de données PostgreSQL créée avec succès dans la région Hawaï ($LOCATION)."

# 🔹 Configuration des règles de pare-feu pour autoriser ton PC à accéder à la base
# 🔹 Vérifier si l'IP est bien au format "nb.nb.nb.nb" (IPv4)
if [[ ! $MY_IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Erreur : L'adresse IP récupérée ($MY_IP_ADDRESS) n'est pas valide."
else
    echo "🔹 Ajout d'une règle de pare-feu pour l'IP actuelle : $MY_IP_ADDRESS"
    az postgres flexible-server firewall-rule create \
        --resource-group $RESOURCE_GROUP \
        --name $POSTGRES_SERVER \
        --rule-name AllowMyIP \
        --start-ip-address $MY_IP_ADDRESS \
        --end-ip-address $MY_IP_ADDRESS

    echo "✅ Accès autorisé pour ton IP actuelle."
fi

# 🔹 Configuration des règles de pare-feu pour autoriser azure shell à accéder à la base
echo "🔹 Ajout d'une règle de pare-feu pour l'IP Azure Shell : 0.0.0.0"
az postgres flexible-server firewall-rule create \
    --resource-group $RESOURCE_GROUP \
    --name $POSTGRES_SERVER \
    --rule-name AllowAzureShell \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0

echo "✅ Accès autorisé pour l'IP Azure Shell."


# 🔹 Vérification du statut du serveur
echo "🔹 Vérification du statut du serveur..."
az postgres flexible-server show \
    --name $POSTGRES_SERVER \
    --resource-group $RESOURCE_GROUP \
    --query "{status: state, haMode: highAvailability}"

# 🔹 Création de la table messages
# 🔍 Vérification des variables nécessaires
if [[ -z "$POSTGRES_USER" || -z "$POSTGRES_PASSWORD" || -z "$POSTGRES_SERVER" ]]; then
  echo "❌ Erreur : Une ou plusieurs variables nécessaires à la connexion PostgreSQL sont vides."
  echo "POSTGRES_USER=$POSTGRES_USER"
  echo "POSTGRES_PASSWORD=${#POSTGRES_PASSWORD} caractères"
  echo "POSTGRES_SERVER=$POSTGRES_SERVER"
  exit 1
fi

# 🔗 Construction de la chaîne de connexion
CONN_STRING="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_SERVER.postgres.database.azure.com:5432/postgres?sslmode=require"
SAFE_CONN_STRING="postgresql://$POSTGRES_USER:*****@$POSTGRES_SERVER.postgres.database.azure.com:5432/postgres?sslmode=require"
echo "🔗 Connexion à PostgreSQL avec : $SAFE_CONN_STRING"

# 🔹 Création de la table messages
echo "🛠️ Création de la table messages..."
psql "$CONN_STRING" -c "CREATE TABLE IF NOT EXISTS messages (
  id VARCHAR(255) PRIMARY KEY,
  content TEXT NOT NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  server TEXT
);" || {
  echo "❌ Échec de la création de la table. Vérifie les logs ci-dessus."
  exit 1
}

echo "🚀 Déploiement terminé. PostgreSQL est prêt à être utilisé dans $LOCATION !"
