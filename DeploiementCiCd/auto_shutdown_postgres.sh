#!/bin/bash

# 🔹 Configuration des variables
RESOURCE_GROUP="DevopsDeploymentManuelRG"
SERVER_NAME="hellodevops-db-postgres"

echo "🚀 Surveillance de l'activité de PostgreSQL Azure ($SERVER_NAME)..."

# 🔹 Vérifier la dernière activité
LAST_QUERY_TIME=$(psql "postgresql://devopsadmin:devopsadmin@$SERVER_NAME.postgres.database.azure.com:5432/postgres?sslmode=require" -c "SELECT max(backend_start) FROM pg_stat_activity;" -t | xargs)

# 🔹 Calculer le temps écoulé depuis la dernière requête
CURRENT_TIME=$(date -u +"%Y-%m-%d %H:%M:%S")
TIME_DIFF=$(($(date -d "$CURRENT_TIME" +%s) - $(date -d "$LAST_QUERY_TIME" +%s)))

# 🔹 Si aucune requête depuis 1 heure (3600 secondes), arrêter la base
if [ "$TIME_DIFF" -gt 3600 ]; then
    echo "⏳ Aucun trafic détecté depuis plus d'1 heure. Arrêt de la base PostgreSQL..."
    az postgres flexible-server stop --name $SERVER_NAME --resource-group $RESOURCE_GROUP
    echo "✅ Serveur PostgreSQL arrêté avec succès !"
else
    echo "✅ Activité détectée récemment, la base reste en ligne."
fi
