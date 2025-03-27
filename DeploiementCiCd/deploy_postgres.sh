#!/bin/bash

# Load .env existant
set -a
. ../.env
set +a

# Creation de nom de base unique
SUFFIX=$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)
POSTGRES_SERVER="${POSTGRES_SERVER_BASE_NAME}-${SUFFIX}"

sed -i "/^POSTGRES_SERVER=/d" ../.env
echo "POSTGRES_SERVER=$POSTGRES_SERVER\n" >> ../.env

echo "🚀 Ajout de  POSTGRES_SERVER=$POSTGRES_SERVER dans .env"

# 🔹 Configuration des variables specifiques a la creation de la base
LOCATION="West US 3"  # ✅ Région Hawaï
MY_IP_ADDRESS=monIpLocal # Remplacer par l'ip locale pour une execution locale

echo "🚀 Déploiement de PostgreSQL Flexible Server en mode Spot sur Azure (Hawaï)..."

# 🔹 Vérifier si le Resource Group existe, sinon le créer
az group show --name $RESOURCE_GROUP &>/dev/null
if [ $? -ne 0 ]; then
    echo "📌 Création du Resource Group $RESOURCE_GROUP..."
    az group create --name $RESOURCE_GROUP --location "$LOCATION"
fi


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
echo "🔹 Création de la table messages..."
psql "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_SERVER.postgres.database.azure.com:5432/postgres?sslmode=require" \
    -c "CREATE TABLE IF NOT EXISTS messages ( \
           id VARCHAR(255) PRIMARY KEY, \
           content TEXT NOT NULL, \
           timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
           server TEXT \
    );"

echo "🚀 Déploiement terminé. PostgreSQL est prêt à être utilisé dans $LOCATION !"
