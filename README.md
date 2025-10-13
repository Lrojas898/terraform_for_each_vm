# Terraform Azure Infrastructure - DevOps Automation

**Autor**: LUIS MANUEL ROJAS CORREA
**Código**: A00399289

## Descripción

Infraestructura como código (IaC) para el despliegue automatizado de máquinas virtuales en Azure usando Terraform. Incluye backend remoto en Azure Storage, pipeline CI/CD para gestión de infraestructura y scripts de automatización para operaciones DevOps.

## Arquitectura del Sistema


<img width="1912" height="1012" alt="image" src="https://github.com/user-attachments/assets/584c3266-ad61-45cc-af1d-52ea73ae7492" />



### Componentes de Infraestructura

**Infraestructura Principal:**
- **Resource Group**: devops-rg (Chile Central)
- **Virtual Network**: devops-network (10.0.0.0/16)
- **Subnet**: devops-subnet (10.0.1.0/24)
- **Network Security Group**: Reglas SSH, HTTP, SonarQube

**Máquinas Virtuales Desplegadas:**

<img width="1903" height="978" alt="image" src="https://github.com/user-attachments/assets/c8aabc7d-9ebd-44b1-931d-15db6242aada" />


1. **jenkins-machine** (68.211.125.173)
   - Rol: CI/CD Server
   - OS: Ubuntu 16.04 LTS
   - Size: Standard_DS1_v2
   - Servicios: Jenkins (puerto 80), SonarQube (puerto 9000)
  
<img width="1903" height="1012" alt="image" src="https://github.com/user-attachments/assets/e63e4d50-1397-4f89-964d-f2f62ffa512f" />


2. **nginx-machine** (68.211.125.160)
   - Rol: Web Server
   - OS: Ubuntu 16.04 LTS
   - Size: Standard_DS1_v2
   - Servicios: Nginx (puerto 80)

<img width="1907" height="1012" alt="image" src="https://github.com/user-attachments/assets/51550966-17f6-45a5-8b5b-e2f53b0ddd8e" />

**Backend de Estado:**
- **Resource Group**: devops-terraform-state-rg
- **Storage Account**: devopsterraformstate001
- **Container**: tfstate
- **State File**: devops-infrastructure.tfstate

### Arquitectura de Red

```
Azure Subscription (44127b49-3951-4881-8cf2-9cff7a88e6ca)
├── devops-rg (Resource Group)
│   ├── devops-network (VNet: 10.0.0.0/16)
│   │   └── devops-subnet (10.0.1.0/24)
│   ├── devops-sg (Network Security Group)
│   │   ├── SSH (port 22)
│   │   ├── HTTP (port 80)
│   │   └── SonarQube (port 9000)
│   ├── jenkins-machine (VM)
│   │   ├── jenkins-nic (Network Interface)
│   │   └── jenkins-public-ip (Static IP)
│   └── nginx-machine (VM)
│       ├── nginx-nic (Network Interface)
│       └── nginx-public-ip (Static IP)
└── devops-terraform-state-rg (Backend)
    └── devopsterraformstate001 (Storage Account)
```

## Estructura del Repositorio

```
terraform_for_each_vm/
├── main.tf                    # Recursos principales (RG, VNet, Subnet)
├── providers.tf               # Proveedor Azure + Backend configuration
├── variables.tf               # Definición de variables
├── terraform.tfvars           # Valores de configuración
├── outputs.tf                 # Outputs de IPs públicas
├── backend.tf                 # Documentación del backend
├── modules/
│   └── vm/
│       ├── main.tf            # VMs, IPs, NICs, NSG
│       ├── variables.tf       # Variables del módulo
│       └── outputs.tf         # Outputs de IPs
├── setup-backend.sh           # Script configuración backend
├── drift-detection.sh         # Script detección de drift
├── azure-credentials.sh       # Script configuración credenciales
├── Jenkinsfile                # Pipeline CI/CD infraestructura
├── .terraform.lock.hcl        # Lock file de providers
└── README.md                  # Esta documentación
```

## Pipeline CI/CD - Jenkins

<img width="1912" height="1041" alt="image" src="https://github.com/user-attachments/assets/c625939a-f0f7-4de7-acad-029c27de7f75" />


### Configuración del Pipeline

**Trigger del Pipeline:**
```groovy
triggers {
    GenericTrigger(
        token: 'terraform-webhook-token',
        regexpFilterExpression: 'refs/heads/main,https://github.com/Lrojas898/terraform_for_each_vm'
    )
}
```

**Variables de Entorno:**
```groovy
environment {
    TF_WORK_DIR = "${env.WORKSPACE}/terraform-workspace"
    TF_VAR_subscription_id = '44127b49-3951-4881-8cf2-9cff7a88e6ca'
    TERRAFORM_REPO = 'https://github.com/Lrojas898/terraform_for_each_vm.git'
    TF_BACKEND_RESOURCE_GROUP = 'devops-terraform-state-rg'
    TF_BACKEND_STORAGE_ACCOUNT = 'devopsterraformstate001'
    TF_BACKEND_CONTAINER = 'tfstate'
    TF_BACKEND_KEY = 'devops-infrastructure.tfstate'
}
```

### Stages del Pipeline

#### Stage 1: Checkout
**Propósito**: Clonar repositorio Terraform desde GitHub

**Proceso:**
- Checkout del repositorio terraform_for_each_vm
- Creación de workspace aislado para Terraform
- Copia de archivos .tf al workspace temporal
- Información de commit y branch

**Duración**: 5-8 segundos

#### Stage 2: Terraform Setup & Validate
**Propósito**: Instalar Terraform y validar configuración

**Proceso:**
- Instalación automática de Terraform 1.6.2 si no existe
- Inicialización sin backend para validación
- Validación de sintaxis con `terraform validate`
- Verificación y corrección de formato con `terraform fmt`

**Comando de validación:**
```bash
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
```

**Duración**: 10-15 segundos

#### Stage 3: Setup Azure Backend
**Propósito**: Configurar autenticación Azure y backend remoto

**Proceso:**
- Instalación de Azure CLI si no existe
- Autenticación con Service Principal
- Verificación de Storage Account backend
- Obtención de credenciales de acceso (ARM_ACCESS_KEY)
- Ejecución de setup-backend.sh si es necesario

**Autenticación:**
```bash
az login --service-principal \
    --username ${ARM_CLIENT_ID} \
    --password ${ARM_CLIENT_SECRET} \
    --tenant e994072b-523e-4bfe-86e2-442c5e10b244
```

**Duración**: 20-30 segundos

#### Stage 4: Terraform Initialize
**Propósito**: Inicializar Terraform con backend remoto

**Proceso:**
- Configuración de ARM_ACCESS_KEY desde archivo
- Inicialización con backend de Azure Storage
- Verificación de conectividad con estado remoto
- Listado de recursos en estado remoto

**Comando:**
```bash
export ARM_ACCESS_KEY=$(cat ${ARM_ACCESS_KEY_FILE})
terraform init -reconfigure
terraform state list
```

**Duración**: 8-12 segundos

#### Stage 5: Terraform Plan
**Propósito**: Generar plan de ejecución y detectar cambios

**Proceso:**
- Ejecución de script drift-detection.sh
- Refresh del estado desde Azure
- Generación de plan con terraform plan -detailed-exitcode
- Análisis de códigos de salida (0: sin cambios, 1: error, 2: cambios detectados)
- Guardado del plan en archivo tfplan

**Códigos de salida:**
- **0**: No hay cambios que aplicar
- **1**: Error en la generación del plan
- **2**: Cambios detectados, plan generado exitosamente

**Duración**: 15-25 segundos

#### Stage 6: Terraform Apply
**Propósito**: Aplicar cambios de infraestructura

**Proceso:**
- Verificación de existencia del archivo tfplan
- Aplicación automática del plan aprobado
- Mostrar outputs de la infraestructura
- Confirmación de aplicación exitosa

**Comando:**
```bash
terraform apply -auto-approve tfplan
terraform output
```

**Duración**: 60-180 segundos (dependiendo de cambios)

## Configuración de Variables

### terraform.tfvars
```hcl
region = "Chile Central"
user = "adminuser"
password = "DevOps2024!@#"
prefix_name = "devops"
servers = ["jenkins", "nginx"]
```

### Variables Definidas
```hcl
variable "region" {
    type = string
    description = "región de despliegue en Azure"
}

variable "servers" {
    type = set(string)
    description = "lista de servidores a desplegar"
}
```

## Módulo VM - Uso de for_each

### Recursos Creados con for_each
```hcl
resource "azurerm_public_ip" "devops_ip" {
    for_each = var.servers  # jenkins, nginx
    name = "${each.value}-public-ip"
    allocation_method = "Static"
    sku = "Standard"
}

resource "azurerm_linux_virtual_machine" "vm_devops" {
    for_each = var.servers
    name = "${each.value}-machine"
    size = var.size_servers
    admin_username = var.user
    admin_password = var.password
    disable_password_authentication = false
}
```

### Network Security Group
```hcl
security_rule {
    name = "SSH"
    priority = 1001
    protocol = "Tcp"
    destination_port_range = "22"
}

security_rule {
    name = "HTTP"
    priority = 1002
    protocol = "Tcp"
    destination_port_range = "80"
}

security_rule {
    name = "Sonar"
    priority = 1003
    protocol = "Tcp"
    destination_port_range = "9000"
}
```

## Scripts de Automatización

### setup-backend.sh
**Propósito**: Configurar Azure Storage Backend automáticamente

**Funcionalidades:**
- Crear Resource Group para estado Terraform
- Crear Storage Account seguro con cifrado
- Configurar Container para archivos tfstate
- Generar configuración de backend

### drift-detection.sh
**Propósito**: Detectar cambios no gestionados en infraestructura

**Funcionalidades:**
- Comparar estado Terraform vs realidad Azure
- Generar reportes de drift en formato texto y JSON
- Códigos de salida para integración CI/CD
- Almacenamiento de reportes con timestamp

### azure-credentials.sh
**Propósito**: Configurar credenciales Azure para automatización

**Funcionalidades:**
- Configurar Service Principal
- Exportar variables de entorno ARM_*
- Validar permisos de suscripción

## Backend Remoto - Azure Storage

### Configuración
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "devops-terraform-state-rg"
    storage_account_name = "devopsterraformstate001"
    container_name       = "tfstate"
    key                  = "devops-infrastructure.tfstate"
  }
}
```

### Ventajas del Backend Remoto
- **Estado compartido**: Múltiples usuarios pueden trabajar
- **Locking**: Previene ejecuciones concurrentes
- **Backup automático**: Azure Storage con redundancia
- **Versionado**: Historial de cambios de estado
- **Seguridad**: Cifrado en tránsito y reposo

## Comandos de Operación

### Despliegue Inicial
```bash
# 1. Configurar backend (solo primera vez)
./setup-backend.sh

# 2. Inicializar Terraform
terraform init

# 3. Planificar despliegue
terraform plan -out=tfplan

# 4. Aplicar cambios
terraform apply tfplan
```

### Operaciones Diarias
```bash
# Detectar drift
./drift-detection.sh

# Ver estado actual
terraform state list
terraform show

# Actualizar desde Azure
terraform refresh

# Destruir recursos (cuidado)
terraform destroy
```

### Gestión de Estado
```bash
# Ver recursos en estado
terraform state list

# Mostrar recurso específico
terraform state show azurerm_linux_virtual_machine.vm_devops[\"jenkins\"]

# Importar recurso existente
terraform import azurerm_resource_group.main /subscriptions/44127b49-3951-4881-8cf2-9cff7a88e6ca/resourceGroups/devops-rg

# Mover recurso en estado
terraform state mv azurerm_resource_group.old azurerm_resource_group.new
```

## Integración con Ecosistema DevOps

### Relación con Otros Repositorios

**terraform_for_each_vm (este repo)**:
- Despliega infraestructura base en Azure
- Crea VMs jenkins-machine y nginx-machine
- Configura red y seguridad

**ansible-pipeline**:
- Usa las VMs creadas por Terraform
- Instala y configura Jenkins y SonarQube
- Ejecuta pipeline CI/CD de aplicaciones

**Teclado**:
- Se despliega en nginx-machine (creada por Terraform)
- Pipeline ejecuta en jenkins-machine (creada por Terraform)
- Usa infraestructura gestionada por este repositorio

### Flujo de Dependencias
```
1. terraform_for_each_vm → Crea infraestructura
2. ansible-pipeline → Configura servicios
3. Teclado → Despliega aplicación
```

## Monitoreo y Troubleshooting

### URLs de Acceso
- **Jenkins**: http://68.211.125.173 (VM creada por Terraform)
- **SonarQube**: http://68.211.125.173:9000 (VM creada por Terraform)
- **Aplicación**: http://68.211.125.160 (VM creada por Terraform)

### Verificación de Recursos
```bash
# Verificar VMs desde Azure CLI
az vm list --resource-group devops-rg --output table

# Ver IPs públicas
az network public-ip list --resource-group devops-rg --output table

# Estado de red
az network nsg list --resource-group devops-rg --output table

# Verificar backend storage
az storage account show --name devopsterraformstate001 --resource-group devops-terraform-state-rg
```

### Problemas Comunes

#### 1. Error de autenticación Azure
**Síntoma**: "Error: authentication failed"
**Causa**: Credenciales Service Principal incorrectas
**Solución**: Verificar ARM_CLIENT_ID y ARM_CLIENT_SECRET

#### 2. Backend storage no accesible
**Síntoma**: "Error: Failed to get existing workspaces"
**Causa**: ARM_ACCESS_KEY incorrecta o Storage Account no existe
**Solución**: Ejecutar setup-backend.sh para recrear backend

#### 3. Terraform state locked
**Síntoma**: "Error: Error acquiring the state lock"
**Causa**: Proceso previo interrumpido sin liberar lock
**Solución**: `terraform force-unlock <LOCK_ID>`

#### 4. Drift detectado
**Síntoma**: Script drift-detection.sh retorna código 2
**Causa**: Cambios manuales en Azure no reflejados en Terraform
**Solución**: Revisar cambios y ejecutar `terraform plan` y `terraform apply`

## Métricas del Pipeline

### Rendimiento
- **Tiempo total promedio**: 3-5 minutos
- **Tiempo por stage**:
  - Checkout: 5-8s
  - Validate: 10-15s
  - Setup Backend: 20-30s
  - Initialize: 8-12s
  - Plan: 15-25s
  - Apply: 60-180s (según cambios)

### Frecuencia de Uso
- **Deploy inicial**: Una vez por proyecto
- **Updates de infraestructura**: Según necesidades
- **Drift detection**: Diario via cron o pipeline

## Seguridad y Mejores Prácticas

### Seguridad Implementada
- Service Principal con permisos mínimos necesarios
- Credenciales almacenadas en Jenkins credentials store
- Backend storage con cifrado TLS 1.2
- Network Security Groups restrictivos
- Passwords seguros para VMs

### Mejores Prácticas Aplicadas
- Uso de módulos para reutilización
- Variables centralizadas en terraform.tfvars
- Backend remoto para trabajo colaborativo
- Versionado de estado con Azure Storage
- Scripts automatizados para operaciones comunes
- Pipeline CI/CD para cambios controlados

### Próximas Mejoras
- Implementar Azure Key Vault para secretos
- Agregar tags de costos y ownership
- Configurar backup policies automatizadas
- Implementar multi-environment (dev, staging, prod)
- Agregar monitoring con Azure Monitor

Este repositorio demuestra la implementación de Infrastructure as Code con Terraform siguiendo las mejores prácticas de DevOps, incluyendo automatización, seguridad y gestión colaborativa de infraestructura.
