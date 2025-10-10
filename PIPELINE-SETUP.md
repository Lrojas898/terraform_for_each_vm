# Configuración del Pipeline de Infraestructura Terraform

## 🚀 Pipeline Creado

He creado un **Jenkinsfile** completo para automatizar el despliegue de infraestructura con los siguientes stages en el orden correcto:

### 📋 Stages del Pipeline (Orden Correcto)

1. **Checkout** - Clona el repositorio terraform_for_each_vm
2. **Terraform Validate** - Valida sintaxis de archivos .tf
3. **Terraform Format** - Verifica y corrige formato del código
4. **Setup Azure Backend** - Configura acceso al Azure Storage Backend
5. **Terraform Initialize** - Inicializa con backend remoto
6. **Terraform Plan** - Genera plan de ejecución y detecta drift
7. **Terraform Apply** - Aplica cambios de infraestructura
8. **Post-Deploy Verification** - Verificación post-despliegue

## 🔧 Configuración del Pipeline en Jenkins

### 1. Crear Nuevo Job en Jenkins

1. Acceder a Jenkins: http://68.211.125.173
2. Hacer clic en "New Item"
3. Nombre: `Terraform-Infrastructure-Pipeline`
4. Seleccionar: "Pipeline"
5. Hacer clic en "OK"

### 2. Configuración del Job

**En la sección "Pipeline":**
- **Definition**: Pipeline script from SCM
- **SCM**: Git
- **Repository URL**: `https://github.com/Lrojas898/terraform_for_each_vm.git`
- **Branch Specifier**: `*/main`
- **Script Path**: `Jenkinsfile`

**IMPORTANTE**:
- ❌ **NO configurar triggers manuales en Jenkins UI**
- ✅ **Los triggers están definidos en el Jenkinsfile** (GenericTrigger)

### 3. Guardar Configuración
Hacer clic en "Save" para guardar la configuración del job.

## 🔗 Configuración del Webhook en GitHub

### 1. Acceder al Repositorio
1. Ir a: https://github.com/Lrojas898/terraform_for_each_vm
2. Ir a: **Settings** → **Webhooks**
3. Hacer clic en **"Add webhook"**

### 2. Configuración del Webhook

**Configuración específica para terraform_for_each_vm:**

```
Payload URL: http://68.211.125.173/generic-webhook-trigger/invoke?token=terraform-webhook-token
Content type: application/json
Secret: (dejar vacío)
```

**Which events would you like to trigger this webhook?**
- Seleccionar: **"Just the push event"**
- ✅ **Active** (asegurarse que esté marcado)

### 3. Verificar Configuración

Después de guardar, deberías ver:
- ✅ Estado verde junto al webhook
- Mensaje: "We delivered this payload successfully"

## 🔑 Variables de Entorno Configuradas

El pipeline utiliza estas variables automáticamente:

```groovy
environment {
    TF_WORKSPACE = '/tmp/terraform-workspace'
    TF_VAR_subscription_id = '44127b49-3951-4881-8cf2-9cff7a88e6ca'
    TERRAFORM_REPO = 'https://github.com/Lrojas898/terraform_for_each_vm.git'

    // Azure Storage Backend
    TF_BACKEND_RESOURCE_GROUP = 'devops-terraform-state-rg'
    TF_BACKEND_STORAGE_ACCOUNT = 'devopsterraformstate001'
    TF_BACKEND_CONTAINER = 'tfstate'
    TF_BACKEND_KEY = 'devops-infrastructure.tfstate'
}
```

## 🧪 Probar el Pipeline

### 1. Test Manual
1. En Jenkins, ir al job `Terraform-Infrastructure-Pipeline`
2. Hacer clic en **"Build Now"**
3. Monitorear la ejecución en **"Console Output"**

### 2. Test con Webhook
1. Hacer un cambio menor en cualquier archivo .tf del repositorio
2. Commit y push al branch `main`:
   ```bash
   git add .
   git commit -m "Test pipeline trigger"
   git push origin main
   ```
3. Verificar que el pipeline se ejecute automáticamente en Jenkins

## 📊 Funcionalidades del Pipeline

### ✅ Características Implementadas

- **Validación automática** de sintaxis Terraform
- **Formateo automático** de código
- **Backend remoto** con Azure Storage
- **Detección de drift** antes y después del despliegue
- **Plan detallado** con revisión de cambios
- **Apply automático** con confirmación
- **Artifacts archivados** (plans, reportes)
- **Reportes JSON** estructurados

### 🔍 Detección de Drift

El pipeline ejecuta automáticamente:
- Detección de drift antes del plan
- Verificación post-despliegue
- Reportes en formato JSON

### 📁 Artifacts Generados

- `plan-output.txt`: Plan detallado de Terraform
- `deployment-report.json`: Reporte estructurado del despliegue
- `drift-reports/*.json`: Reportes de detección de drift

## 🚨 Troubleshooting

### Pipeline No Se Ejecuta Automáticamente

1. **Verificar webhook en GitHub:**
   - Ir a Settings → Webhooks
   - Revisar "Recent Deliveries"
   - Debe mostrar status 200 OK

2. **Verificar token en Jenkinsfile:**
   - Token debe ser: `terraform-webhook-token`
   - URL debe apuntar a: `https://github.com/Lrojas898/terraform_for_each_vm`

### Error de Autenticación Azure

```bash
Error: Failed to authenticate with Azure
```

**Solución:**
1. Verificar que Azure CLI esté instalado en Jenkins
2. Configurar service principal si es necesario
3. Verificar permisos de la suscripción

### Error de Backend

```bash
Error: Backend initialization failed
```

**Solución:**
1. Ejecutar script setup-backend.sh manualmente
2. Verificar que el Storage Account existe
3. Revisar credenciales de acceso

## 📋 Checklist de Configuración

- [ ] ✅ Jenkinsfile creado en repositorio terraform_for_each_vm
- [ ] ⏳ Pipeline configurado en Jenkins
- [ ] ⏳ Webhook configurado en GitHub
- [ ] ⏳ Test manual del pipeline exitoso
- [ ] ⏳ Test automático con webhook exitoso

## 🎯 Próximos Pasos

1. **Configurar el pipeline en Jenkins** según las instrucciones
2. **Configurar el webhook en GitHub**
3. **Hacer un test push** para verificar funcionamiento
4. **Monitorear logs** para asegurar ejecución correcta

¡El pipeline está listo para automatizar completamente el despliegue de tu infraestructura Terraform!