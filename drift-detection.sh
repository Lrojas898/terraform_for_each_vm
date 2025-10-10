#!/bin/bash

# Script para detección de drift en infraestructura Terraform
# Autor: DevOps Pipeline Setup

set -e

echo "=== Detección de Drift en Infraestructura ==="

# Variables de configuración
RESOURCE_GROUP="devops-terraform-state-rg"
STORAGE_ACCOUNT="devopsterraformstate001"
REPORT_DIR="./drift-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Verificar requisitos
echo "Verificando requisitos previos..."

if ! command -v terraform &> /dev/null; then
    echo "ERROR: Terraform no está instalado."
    exit 1
fi

if ! command -v az &> /dev/null; then
    echo "ERROR: Azure CLI no está instalado."
    exit 1
fi

if ! az account show &> /dev/null; then
    echo "ERROR: No está autenticado en Azure. Ejecute 'az login' primero."
    exit 1
fi

echo "✓ Requisitos verificados"

# Configurar credenciales para el backend
echo "Configurando acceso al estado remoto..."
ACCOUNT_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP" --account-name "$STORAGE_ACCOUNT" --query '[0].value' -o tsv)
export ARM_ACCESS_KEY="$ACCOUNT_KEY"

# Crear directorio de reportes
mkdir -p "$REPORT_DIR"

echo "✓ Credenciales configuradas"

# Inicializar Terraform si es necesario
echo "Inicializando Terraform..."
terraform init -input=false

# Refresh del estado
echo "Actualizando estado desde Azure..."
terraform refresh -input=false

# Ejecutar plan para detectar drift
echo "Ejecutando detección de drift..."
PLAN_OUTPUT="$REPORT_DIR/drift-plan-$TIMESTAMP.txt"
EXIT_CODE=0

terraform plan -detailed-exitcode -input=false -no-color > "$PLAN_OUTPUT" 2>&1 || EXIT_CODE=$?

# Analizar resultado
echo ""
echo "=== Resultado de la Detección de Drift ==="

case $EXIT_CODE in
    0)
        echo "✅ NO HAY DRIFT - La infraestructura coincide con la configuración"
        echo "Estado: ESTABLE"
        ;;
    1)
        echo "❌ ERROR - Falló la ejecución del plan"
        echo "Estado: ERROR"
        echo "Revise el archivo: $PLAN_OUTPUT"
        ;;
    2)
        echo "⚠️  DRIFT DETECTADO - Hay diferencias entre la configuración y el estado real"
        echo "Estado: DRIFT DETECTADO"
        echo ""
        echo "Cambios detectados:"
        grep -A 5 -B 5 "Plan:" "$PLAN_OUTPUT" || echo "Ver detalles en: $PLAN_OUTPUT"
        ;;
    *)
        echo "❓ CÓDIGO DE SALIDA DESCONOCIDO: $EXIT_CODE"
        echo "Estado: DESCONOCIDO"
        ;;
esac

# Generar reporte JSON
echo "Generando reporte JSON..."
REPORT_JSON="$REPORT_DIR/drift-report-$TIMESTAMP.json"

cat > "$REPORT_JSON" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "exit_code": $EXIT_CODE,
  "status": "$(case $EXIT_CODE in 0) echo "STABLE";; 1) echo "ERROR";; 2) echo "DRIFT";; *) echo "UNKNOWN";; esac)",
  "terraform_version": "$(terraform version -json | jq -r '.terraform_version')",
  "plan_file": "$PLAN_OUTPUT",
  "azure_subscription": "$(az account show --query 'id' -o tsv)",
  "resource_group": "$RESOURCE_GROUP",
  "storage_account": "$STORAGE_ACCOUNT"
}
EOF

echo "✓ Reporte JSON generado: $REPORT_JSON"

# Mostrar resumen de archivos
echo ""
echo "Archivos generados:"
echo "- Plan detallado: $PLAN_OUTPUT"
echo "- Reporte JSON: $REPORT_JSON"

# Listar recursos en el estado
echo ""
echo "Recursos gestionados por Terraform:"
terraform state list

echo ""
echo "=== Detección de Drift Completada ==="
echo "Timestamp: $(date)"
echo "Exit Code: $EXIT_CODE"

# Salir con el código de Terraform para integración con CI/CD
exit $EXIT_CODE