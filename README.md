# Terraform Infrastructure as Code

**Autor**: LUIS MANUEL ROJAS CORREA
**Código**: A00399289

## Descripción

Configuración de Terraform para provisionar infraestructura de pipeline DevOps con Jenkins y SonarQube en Azure. Implementa Infrastructure as Code (IaC) con módulos reutilizables.

## Arquitectura

### Recursos Azure

**Resource Group**: `devops-rg`
**Región**: Chile Central

#### Máquinas Virtuales

1. **jenkins-machine** (68.211.125.173)
   - Jenkins CI/CD (puerto 80)
   - SonarQube (puerto 9000)
   - Ubuntu 22.04 LTS
   - 4GB RAM, 2 vCPUs

2. **nginx-machine** (68.211.125.160)
   - Nginx web server (puerto 80)
   - Ubuntu 22.04 LTS
   - 2GB RAM, 1 vCPU

#### Red

- Red Virtual con subnetting interno
- IPs públicas estáticas
- Network Security Groups con reglas para SSH (22), HTTP (80), SonarQube (9000)

## Estructura del Proyecto

```
terraform_for_each_vm/
├── main.tf              # Configuración principal de recursos
├── variables.tf         # Definición de variables
├── outputs.tf          # Outputs de recursos creados
├── providers.tf        # Configuración de providers Azure
├── terraform.tfvars    # Valores de variables (configuración específica)
├── .gitignore         # Archivos ignorados por Git
└── modules/           # Módulos reutilizables
    └── vm/           # Módulo para creación de VMs
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Configuración Específica

### Variables Principales

```hcl
# terraform.tfvars
region = "Chile Central"
password = "DevOps2024!@#"
```

### Decisiones Técnicas

1. **Región**: Chile Central (cambio desde East US por limitaciones de cuota estudiantil)
2. **Password**: Cumple políticas Azure con caracteres especiales
3. **Módulos**: Separación entre red, seguridad y cómputo para reutilización

## Proceso de Despliegue

### Prerrequisitos

```bash
# Instalar Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Configurar Azure CLI
az login
az account set --subscription "your-subscription-id"
```

### Comandos de Ejecución

```bash
# Inicializar Terraform
terraform init

# Planificar cambios
terraform plan

# Aplicar configuración
terraform apply

# Verificar estado
terraform show

# Destruir recursos (si necesario)
terraform destroy
```

## Problemas Resueltos

### 1. Limitaciones de Suscripción Estudiantil

**Problema**: Cuota insuficiente en región East US
**Error**: `QuotaExceeded: Operation could not be completed as it results in exceeding approved quota`
**Solución**: Migración a región Chile Central con disponibilidad confirmada
**Impacto**: Cambio mínimo en latencia, funcionalidad completa preservada

### 2. Políticas de Password Azure

**Problema**: Password inicial no cumplía políticas de Azure
**Error**: `Password does not meet complexity requirements`
**Solución**: Implementación de password con caracteres especiales: `DevOps2024!@#`
**Validación**: Cumple requisitos de longitud, mayúsculas, números y símbolos

### 3. Configuración de Network Security Groups

**Problema**: Acceso bloqueado a servicios por reglas de firewall por defecto
**Solución**: Configuración específica de reglas para:
- SSH (22) desde cualquier origen para administración
- HTTP (80) para Jenkins y aplicación web
- Puerto 9000 para SonarQube
- Restricciones de origen apropiadas para seguridad

## Outputs Importantes

Después del despliegue exitoso, Terraform proporciona:

```hcl
jenkins_public_ip = "68.211.125.173"
nginx_public_ip = "68.211.125.160"
resource_group_name = "devops-rg"
jenkins_ssh_command = "ssh adminuser@68.211.125.173"
nginx_ssh_command = "ssh adminuser@68.211.125.160"
```

## Verificación Post-Despliegue

### Conectividad SSH

```bash
# Conexión a Jenkins VM
ssh adminuser@68.211.125.173

# Conexión a Nginx VM
ssh adminuser@68.211.125.160
```

### Verificación de Servicios

```bash
# En jenkins-machine
docker ps  # Verificar contenedores Jenkins y SonarQube
curl localhost:8080  # Jenkins health check
curl localhost:9000  # SonarQube health check

# En nginx-machine
systemctl status nginx  # Estado del servicio Nginx
curl localhost  # Verificar respuesta web
```

## Mantenimiento y Evolución

### Actualizaciones de Infraestructura

1. Modificar variables en `terraform.tfvars`
2. Ejecutar `terraform plan` para revisar cambios
3. Aplicar con `terraform apply`
4. Verificar estado con `terraform show`

### Escalabilidad

La arquitectura modular permite:
- Adición de nuevas VMs mediante el módulo existente
- Modificación de tamaños de instancia sin recreación
- Implementación de load balancers para alta disponibilidad
- Integración con otros servicios de Azure (databases, storage, etc.)

## Recursos de Azure Creados

- **Resource Group**: Contenedor principal de recursos
- **Virtual Network**: Red privada con subnetting apropiado
- **2 Network Security Groups**: Reglas de firewall específicas
- **2 Public IPs**: IPs estáticas para acceso externo
- **2 Network Interfaces**: Conexión de VMs a la red
- **2 Virtual Machines**: Instancias Ubuntu 22.04 LTS
- **2 OS Disks**: Almacenamiento persistente para VMs

## Costos y Optimización

**Configuración actual**:
- jenkins-machine: Standard_B2s (2 vCPUs, 4GB RAM)
- nginx-machine: Standard_B1s (1 vCPU, 1GB RAM)
- Storage: Premium SSD para mejor rendimiento
- Costo estimado: ~$50-70 USD/mes

**Optimizaciones implementadas**:
- Uso de instancias B-series (burstable) para cargas variables
- Storage optimizado por tipo de workload
- Network Security Groups específicos para minimizar superficie de ataque

Este repositorio forma parte del proyecto completo de DevOps disponible en: `devops-jenkins-sonarqube-pipeline`