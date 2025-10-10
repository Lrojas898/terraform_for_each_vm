#!/bin/bash

# Script para migrar el estado de Terraform de local a Azure Storage Backend
# Autor: DevOps Pipeline Setup

set -e

echo "=== Migración de Estado de Terraform a Azure Storage Backend ==="

# Variables de configuración
BACKUP_DIR="./terraform-state-backup"
STATE_FILE="terraform.tfstate"

echo "Verificando requisitos previos..."

# Verificar si Terraform está instalado
if ! command -v terraform &> /dev/null; then
    echo "ERROR: Terraform no está instalado."
    exit 1
fi

# Verificar si Azure CLI está instalado
if ! command -v az &> /dev/null; then
    echo "ERROR: Azure CLI no está instalado."
    exit 1
fi

# Verificar login en Azure
if ! az account show &> /dev/null; then
    echo "ERROR: No está autenticado en Azure. Ejecute 'az login' primero."
    exit 1
fi

echo "✓ Requisitos verificados"

# Crear directorio de backup
echo "Creando backup del estado actual..."
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Backup del estado local si existe
if [ -f "$STATE_FILE" ]; then
    cp "$STATE_FILE" "$BACKUP_DIR/terraform.tfstate.backup_$TIMESTAMP"
    echo "✓ Backup del estado local creado: $BACKUP_DIR/terraform.tfstate.backup_$TIMESTAMP"
else
    echo "! No se encontró estado local. Procediendo con inicialización limpia."
fi

# Backup de archivos de configuración
if [ -f "$STATE_FILE.backup" ]; then
    cp "$STATE_FILE.backup" "$BACKUP_DIR/"
fi

# Verificar que el Azure Storage esté configurado
echo "Verificando configuración de Azure Storage..."
RESOURCE_GROUP="devops-terraform-state-rg"
STORAGE_ACCOUNT="devopsterraformstate001"

if ! az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo "ERROR: Azure Storage Account no configurado. Ejecute './setup-backend.sh' primero."
    exit 1
fi

# Obtener access key
echo "Obteniendo credenciales de Azure Storage..."
ACCOUNT_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP" --account-name "$STORAGE_ACCOUNT" --query '[0].value' -o tsv)

# Configurar variable de entorno
export ARM_ACCESS_KEY="$ACCOUNT_KEY"

echo "✓ Credenciales configuradas"

# Reinicializar Terraform con el nuevo backend
echo "Reinicializando Terraform con backend remoto..."
terraform init -reconfigure

echo "✓ Terraform reinicializado con backend de Azure Storage"

# Verificar estado
echo "Verificando estado remoto..."
terraform state list

echo ""
echo "=== Migración completada exitosamente ==="
echo ""
echo "Estado de Terraform ahora se almacena en:"
echo "- Resource Group: $RESOURCE_GROUP"
echo "- Storage Account: $STORAGE_ACCOUNT"
echo "- Container: tfstate"
echo "- Key: devops-infrastructure.tfstate"
echo ""
echo "Backup local guardado en: $BACKUP_DIR/"
echo ""
echo "Para trabajar con este estado remoto, configure:"
echo "export ARM_ACCESS_KEY=\"[redacted]\""
echo ""
echo "Comandos útiles:"
echo "- terraform plan    # Planificar cambios"
echo "- terraform apply   # Aplicar cambios"
echo "- terraform state list  # Listar recursos en el estado"
echo ""