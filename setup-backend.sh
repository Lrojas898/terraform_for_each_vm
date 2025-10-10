#!/bin/bash

# Script para configurar Azure Storage Backend para Terraform State
# Autor: DevOps Pipeline Setup

set -e

echo "=== Configurando Azure Storage Backend para Terraform State ==="

# Variables de configuración
RESOURCE_GROUP="devops-terraform-state-rg"
STORAGE_ACCOUNT="devopsterraformstate001"
CONTAINER_NAME="tfstate"
LOCATION="Chile Central"

echo "Configuración:"
echo "- Resource Group: $RESOURCE_GROUP"
echo "- Storage Account: $STORAGE_ACCOUNT"
echo "- Container: $CONTAINER_NAME"
echo "- Location: $LOCATION"
echo ""

# Verificar si Azure CLI está instalado
if ! command -v az &> /dev/null; then
    echo "ERROR: Azure CLI no está instalado. Instale Azure CLI primero."
    exit 1
fi

# Verificar login en Azure
echo "Verificando autenticación en Azure..."
if ! az account show &> /dev/null; then
    echo "No está autenticado en Azure. Ejecute 'az login' primero."
    exit 1
fi

echo "✓ Autenticado en Azure correctamente"

# Crear Resource Group si no existe
echo "Verificando Resource Group..."
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo "Creando Resource Group: $RESOURCE_GROUP"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo "✓ Resource Group creado"
else
    echo "✓ Resource Group ya existe"
fi

# Crear Storage Account si no existe
echo "Verificando Storage Account..."
if ! az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo "Creando Storage Account: $STORAGE_ACCOUNT"
    az storage account create \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "Standard_LRS" \
        --kind "StorageV2" \
        --access-tier "Hot" \
        --allow-blob-public-access false \
        --min-tls-version "TLS1_2"
    echo "✓ Storage Account creado"
else
    echo "✓ Storage Account ya existe"
fi

# Obtener access key del Storage Account
echo "Obteniendo access key..."
ACCOUNT_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP" --account-name "$STORAGE_ACCOUNT" --query '[0].value' -o tsv)

# Crear Container si no existe
echo "Verificando Container..."
if ! az storage container show --name "$CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT" --account-key "$ACCOUNT_KEY" &> /dev/null; then
    echo "Creando Container: $CONTAINER_NAME"
    az storage container create \
        --name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$ACCOUNT_KEY" \
        --public-access off
    echo "✓ Container creado"
else
    echo "✓ Container ya existe"
fi

echo ""
echo "=== Azure Storage Backend configurado exitosamente ==="
echo ""
echo "Variables de entorno para configurar el backend:"
echo "export ARM_ACCESS_KEY=\"$ACCOUNT_KEY\""
echo ""
echo "Configuración del backend en backend.tf:"
echo "backend \"azurerm\" {"
echo "  resource_group_name  = \"$RESOURCE_GROUP\""
echo "  storage_account_name = \"$STORAGE_ACCOUNT\""
echo "  container_name       = \"$CONTAINER_NAME\""
echo "  key                  = \"devops-infrastructure.tfstate\""
echo "}"
echo ""
echo "Para inicializar el backend, ejecute:"
echo "terraform init -reconfigure"
echo ""