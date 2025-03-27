#!/bin/bash

# 🔹 Configuration des variables
RESOURCE_GROUP="DevopsDeploymentManuelRG"
AUTOMATION_ACCOUNT="AutoShutdownPostgres"
RUNBOOK_NAME="ShutdownPostgres"
SERVER_NAME="hellodevops-db-postgres"
LOCATION="West US 3"  # Adapter si nécessaire

echo "🚀 Déploiement d'Azure Automation pour arrêt programmé de PostgreSQL..."

az extension add --upgrade -n automation

# 🔹 Vérifier si l'Automation Account existe déjà
EXISTING_ACCOUNT=$(az automation account show --name $AUTOMATION_ACCOUNT --resource-group $RESOURCE_GROUP --query "name" -o tsv 2>/dev/null)

if [ -z "$EXISTING_ACCOUNT" ]; then
    echo "🔹 Création de l'Automation Account..."
    az automation account create \
        --name $AUTOMATION_ACCOUNT \
        --resource-group $RESOURCE_GROUP \
        --location "$LOCATION"
else
    echo "✅ L'Automation Account existe déjà."
fi

# 🔹 Vérifier si le Runbook existe déjà
EXISTING_RUNBOOK=$(az automation runbook show --automation-account-name $AUTOMATION_ACCOUNT --resource-group $RESOURCE_GROUP --name $RUNBOOK_NAME --query "name" -o tsv 2>/dev/null)

if [ -z "$EXISTING_RUNBOOK" ]; then
    echo "🔹 Création du Runbook..."
    az automation runbook create \
        --automation-account-name $AUTOMATION_ACCOUNT \
        --resource-group $RESOURCE_GROUP \
        --name $RUNBOOK_NAME \
        --type PowerShell \
        --description "Arrête PostgreSQL toutes les heures"
else
    echo "✅ Le Runbook existe déjà."
fi

# 🔹 Ajouter le script PowerShell simplifié au Runbook
echo "🔹 Mise à jour du script PowerShell dans le Runbook..."
az automation runbook replace-content \
    --automation-account-name $AUTOMATION_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --name $RUNBOOK_NAME \
    --content '
param (
    [string]$ResourceGroup = "'$RESOURCE_GROUP'",
    [string]$ServerName = "'$SERVER_NAME'"
)

# 🔹 Vérifier le statut du serveur PostgreSQL
$Status = az postgres flexible-server show --name $ServerName --resource-group $ResourceGroup --query "state" -o tsv

if ($Status -eq "Ready") {
    Write-Output "🔹 Arrêt du serveur PostgreSQL..."
    az postgres flexible-server stop --name $ServerName --resource-group $ResourceGroup
    Write-Output "✅ Serveur PostgreSQL arrêté."
} else {
    Write-Output "✅ PostgreSQL est déjà arrêté."
}'

# 🔹 Vérifier si la planification existe déjà
EXISTING_SCHEDULE=$(az automation schedule show --automation-account-name $AUTOMATION_ACCOUNT --resource-group $RESOURCE_GROUP --name "ShutdownPostgresHourly" --query "name" -o tsv 2>/dev/null)

if [ -z "$EXISTING_SCHEDULE" ]; then
    echo "🔹 Création de la planification..."
    az automation schedule create \
        --automation-account-name $AUTOMATION_ACCOUNT \
        --resource-group $RESOURCE_GROUP \
        --name "ShutdownPostgresHourly" \
        --description "Arrête PostgreSQL toutes les heures" \
        --frequency Hour \
        --interval 1
else
    echo "✅ La planification existe déjà."
fi

# 🔹 Associer le Runbook à la planification
echo "🔹 Association du Runbook avec la planification..."
az automation job create \
    --automation-account-name $AUTOMATION_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --runbook-name $RUNBOOK_NAME \
    --parameters ResourceGroup=$RESOURCE_GROUP ServerName=$SERVER_NAME

echo "✅ Déploiement terminé : PostgreSQL sera arrêté automatiquement toutes les heures ! 🚀"
