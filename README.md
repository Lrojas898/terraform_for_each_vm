# Terraform Azure Infrastructure con Backend Remoto

**Autor**: LUIS MANUEL ROJAS CORREA
**Código**: A00399289
**Proyecto**: DevOps Infrastructure as Code

## Descripción

Este repositorio contiene la definición de infraestructura como código (IaC) para el despliegue de máquinas virtuales en Azure usando Terraform con backend remoto en Azure Storage para gestión de estado centralizada.

## Arquitectura Multi-Repositorio

Este repositorio forma parte de una arquitectura DevOps que utiliza 3 repositorios independientes:

1. **[Teclado](https://github.com/Lrojas898/Teclado)**: Código fuente de la aplicación web
2. **[ansible-pipeline](https://github.com/Lrojas898/ansible-pipeline)**: Configuración del pipeline CI/CD
3. **[terraform_for_each_vm](https://github.com/Lrojas898/terraform_for_each_vm)** (este repo): Infraestructura como código

## ✨ Nuevas Características - Azure Storage Backend

### Estado Remoto Centralizado
- **Backend**: Azure Storage Account
- **Ventajas**:
  - Estado compartido entre equipos
  - Locking automático para prevenir conflictos
  - Backup automático y versionado
  - Detección de drift de infraestructura

### Configuración del Backend
```hcl
backend "azurerm" {
  resource_group_name  = "devops-terraform-state-rg"
  storage_account_name = "devopsterraformstate001"
  container_name       = "tfstate"
  key                  = "devops-infrastructure.tfstate"
}
```

## Estructura del Proyecto

```
terraform_for_each_vm/
├── main.tf                    # Recursos principales
├── providers.tf               # Proveedor Azure + Backend
├── variables.tf               # Definición de variables
├── terraform.tfvars           # Valores de variables
├── outputs.tf                 # Outputs del proyecto
├── backend.tf                 # Documentación backend
├── modules/                   # Módulos reutilizables
│   └── vm/                   # Módulo de VMs
├── setup-backend.sh          # ✨ Script configuración backend
├── migrate-state.sh          # ✨ Script migración de estado
├── drift-detection.sh        # ✨ Script detección de drift
└── README.md                 # Esta documentación
```

## Scripts de Automatización

### 1. 🚀 Setup Backend (`setup-backend.sh`)
Configura automáticamente el Azure Storage Account para el backend:

```bash
./setup-backend.sh
```

**Funcionalidades**:
- Crea Resource Group para estado de Terraform
- Crea Storage Account seguro con cifrado
- Configura Container para tfstate
- Genera configuración automática

### 2. 🔄 Migración de Estado (`migrate-state.sh`)
Migra el estado local a Azure Storage Backend:

```bash
./migrate-state.sh
```

**Funcionalidades**:
- Backup automático del estado local
- Migración segura a backend remoto
- Verificación de conectividad
- Configuración de credenciales

### 3. 🔍 Detección de Drift (`drift-detection.sh`)
Detecta cambios no gestionados en la infraestructura:

```bash
./drift-detection.sh
```

**Funcionalidades**:
- Comparación estado vs realidad
- Reportes en texto y JSON
- Integración con CI/CD
- Alertas automáticas

## Configuración Inicial

### Variables de Configuración
```hcl
region = "Chile Central"
user = "adminuser"
password = "DevOps2024!@#"
prefix_name = "devops"
servers = ["jenkins", "nginx"]
```

## Flujo de Trabajo Recomendado

### 1. Configuración Inicial (Solo una vez)
```bash
# 1. Configurar backend remoto
./setup-backend.sh

# 2. Migrar estado existente (si aplica)
./migrate-state.sh

# 3. Inicializar con backend remoto
terraform init
```

### 2. Trabajo Diario
```bash
# 1. Detectar drift antes de cambios
./drift-detection.sh

# 2. Planificar cambios
terraform plan

# 3. Aplicar cambios
terraform apply

# 4. Verificar estado post-cambios
./drift-detection.sh
```

## Recursos Creados

### 1. Infraestructura Principal
- **Resource Group**: `devops-rg`
- **Virtual Network**: `devops-network` (10.0.0.0/16)
- **Subnet**: `devops-subnet` (10.0.1.0/24)

### 2. Máquinas Virtuales
- **jenkins-machine** (68.211.125.173):
  - Jenkins CI/CD Server (puerto 80)
  - SonarQube Quality Gate (puerto 9000)
  - Ubuntu 22.04 LTS, 4GB RAM

- **nginx-machine** (68.211.125.160):
  - Servidor web Nginx (puerto 80)
  - Destino de despliegue
  - Ubuntu 22.04 LTS, 2GB RAM

### 3. Backend de Estado (Nuevo)
- **Resource Group**: `devops-terraform-state-rg`
- **Storage Account**: `devopsterraformstate001`
- **Container**: `tfstate`
- **Cifrado**: TLS 1.2, acceso privado

## Comandos Útiles

### Estado y Gestión
```bash
# Listar recursos gestionados
terraform state list

# Ver estado de un recurso específico
terraform state show azurerm_resource_group.main

# Refresh estado desde Azure
terraform refresh

# Importar recurso existente
terraform import azurerm_resource_group.example /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example
```

### Detección de Problemas
```bash
# Validar configuración
terraform validate

# Formatear código
terraform fmt

# Verificar drift
./drift-detection.sh

# Plan con salida detallada
terraform plan -detailed-exitcode
```

## Integración con CI/CD

### Pipeline de Infraestructura
```yaml
# Ejemplo de integración en Azure DevOps/GitHub Actions
- name: Drift Detection
  run: |
    cd terraform_for_each_vm
    ./drift-detection.sh

- name: Terraform Plan
  run: terraform plan -detailed-exitcode

- name: Terraform Apply
  run: terraform apply -auto-approve
  if: github.ref == 'refs/heads/main'
```

## Monitoreo y Alertas

### Códigos de Salida Drift Detection
- **0**: Sin drift, infraestructura estable
- **1**: Error en la ejecución
- **2**: Drift detectado, requiere atención

### Archivos de Reporte
- `drift-reports/drift-plan-TIMESTAMP.txt`: Plan detallado
- `drift-reports/drift-report-TIMESTAMP.json`: Reporte estructurado

## Troubleshooting

### Backend No Configurado
```bash
Error: Backend initialization required
Solución: ./setup-backend.sh
```

### Error de Credenciales
```bash
Error: storage account key not found
Solución: az login && export ARM_ACCESS_KEY=$(az storage account keys list ...)
```

### Conflicto de Estado
```bash
Error: Error acquiring the state lock
Solución: terraform force-unlock <LOCK_ID>
```

### Drift Detectado
```bash
Status: DRIFT DETECTADO
Acción: Revisar cambios y ejecutar terraform apply
```

## Mejores Prácticas Implementadas

### 1. Seguridad
- ✅ Estado remoto cifrado
- ✅ Credenciales mediante Azure CLI
- ✅ Network Security Groups configurados
- ✅ Backup automático de estado

### 2. Operaciones
- ✅ Scripts de automatización
- ✅ Detección de drift automatizada
- ✅ Reportes estructurados
- ✅ Integración CI/CD ready

### 3. Mantenimiento
- ✅ Backup automático antes de cambios
- ✅ Versionado de estado
- ✅ Documentación actualizada
- ✅ Validación de configuración

## Estado Actual

✅ **Backend Remoto**: Configurado y funcionando
✅ **Scripts de Automatización**: Implementados
✅ **Detección de Drift**: Operativa
✅ **Infraestructura**: Desplegada en Chile Central
✅ **Integración**: Lista para CI/CD

### Última Actualización
- **Fecha**: Octubre 2025
- **Cambios**: Azure Storage Backend implementado
- **Status**: ✅ PRODUCCIÓN - FUNCIONANDO

## URLs de Acceso

- **Jenkins**: http://68.211.125.173
- **SonarQube**: http://68.211.125.173:9000
- **Aplicación**: http://68.211.125.160