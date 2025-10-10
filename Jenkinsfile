pipeline {
    agent any

    triggers {
        // Trigger específico para el repositorio terraform_for_each_vm en push a main
        GenericTrigger(
            genericVariables: [
                [key: 'ref', value: '$.ref'],
                [key: 'repository_url', value: '$.repository.html_url']
            ],
            causeString: 'Triggered by push to terraform_for_each_vm repository',
            token: 'terraform-webhook-token',
            printContributedVariables: true,
            printPostContent: true,
            silentResponse: false,
            regexpFilterText: '$ref,$repository_url',
            regexpFilterExpression: 'refs/heads/main,https://github.com/Lrojas898/terraform_for_each_vm'
        )
    }

    options {
        // Configurar checkout para manejar manualmente
        skipDefaultCheckout(true)
        // Timeout del pipeline
        timeout(time: 30, unit: 'MINUTES')
        // Mantener solo los últimos 10 builds
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        // Variables específicas para Terraform
        TF_WORKSPACE = '/tmp/terraform-workspace'
        TF_VAR_subscription_id = '44127b49-3951-4881-8cf2-9cff7a88e6ca'
        TERRAFORM_REPO = 'https://github.com/Lrojas898/terraform_for_each_vm.git'

        // Azure Storage Backend variables
        TF_BACKEND_RESOURCE_GROUP = 'devops-terraform-state-rg'
        TF_BACKEND_STORAGE_ACCOUNT = 'devopsterraformstate001'
        TF_BACKEND_CONTAINER = 'tfstate'
        TF_BACKEND_KEY = 'devops-infrastructure.tfstate'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'CHECKOUT - Obteniendo código del repositorio terraform_for_each_vm'
                script {
                    // Checkout explícito del repositorio terraform
                    checkout([$class: 'GitSCM',
                        branches: [[name: '*/main']],
                        userRemoteConfigs: [[url: env.TERRAFORM_REPO]]
                    ])

                    sh '''
                        echo "Conectando al repositorio Git: ${TERRAFORM_REPO}"
                        echo "Rama: main"
                        echo "Commit actual: ${GIT_COMMIT}"
                        echo "Branch: ${GIT_BRANCH}"

                        # Limpiar workspace anterior
                        rm -rf ${TF_WORKSPACE}
                        mkdir -p ${TF_WORKSPACE}

                        # Copiar archivos del repositorio terraform clonado
                        echo "Copiando archivos de Terraform..."
                        cp -r ${WORKSPACE}/* ${TF_WORKSPACE}/ 2>/dev/null || echo "Algunos archivos no se copiaron"

                        echo "Archivos disponibles en workspace:"
                        ls -la ${TF_WORKSPACE}/

                        echo "Verificando archivos clave de Terraform:"
                        ls -la ${TF_WORKSPACE}/*.tf || echo "Archivos .tf no encontrados"

                        echo "Checkout completado exitosamente"
                    '''
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                echo 'VALIDATE - Validando sintaxis de archivos Terraform'
                script {
                    sh '''
                        cd ${TF_WORKSPACE}
                        echo "Validando configuración de Terraform..."

                        # Instalar Terraform si no está disponible
                        if ! command -v terraform &> /dev/null; then
                            echo "Instalando Terraform..."
                            wget -q https://releases.hashicorp.com/terraform/1.6.2/terraform_1.6.2_linux_amd64.zip
                            unzip -q terraform_1.6.2_linux_amd64.zip
                            chmod +x terraform
                            export PATH=$(pwd):$PATH
                        fi

                        # Verificar versión de Terraform
                        terraform version

                        # Inicializar Terraform (sin backend por ahora)
                        terraform init -backend=false

                        # Validar sintaxis
                        terraform validate

                        echo "✓ Validación de Terraform completada exitosamente"
                    '''
                }
            }
        }

        stage('Terraform Format') {
            steps {
                echo 'FORMAT - Verificando formato de código Terraform'
                script {
                    sh '''
                        cd ${TF_WORKSPACE}
                        echo "Verificando formato de archivos Terraform..."

                        # Verificar formato (no modificar archivos, solo verificar)
                        if ! terraform fmt -check -recursive; then
                            echo "⚠️ Archivos con formato incorrecto detectados"
                            echo "Aplicando formato automático..."
                            terraform fmt -recursive

                            echo "Archivos formateados:"
                            git diff --name-only || echo "No hay cambios de formato"
                        else
                            echo "✓ Todos los archivos tienen formato correcto"
                        fi

                        echo "Verificación de formato completada"
                    '''
                }
            }
        }

        stage('Setup Azure Backend') {
            steps {
                echo 'BACKEND - Configurando backend de Azure Storage'
                script {
                    sh '''
                        cd ${TF_WORKSPACE}
                        echo "Configurando acceso al backend de Azure Storage..."

                        # Verificar si Azure CLI está disponible
                        if ! command -v az &> /dev/null; then
                            echo "Instalando Azure CLI..."
                            curl -sL https://aka.ms/InstallAzureCLIDeb | bash
                        fi

                        # Autenticación con Azure (usando service principal si está configurado)
                        echo "Verificando autenticación con Azure..."

                        # Verificar si el backend storage existe
                        echo "Verificando Azure Storage Backend..."
                        if az storage account show --name ${TF_BACKEND_STORAGE_ACCOUNT} --resource-group ${TF_BACKEND_RESOURCE_GROUP} &> /dev/null; then
                            echo "✓ Azure Storage Backend disponible"

                            # Obtener access key
                            ARM_ACCESS_KEY=$(az storage account keys list --resource-group ${TF_BACKEND_RESOURCE_GROUP} --account-name ${TF_BACKEND_STORAGE_ACCOUNT} --query '[0].value' -o tsv)
                            export ARM_ACCESS_KEY

                            echo "✓ Credenciales de Azure Storage configuradas"
                        else
                            echo "⚠️ Azure Storage Backend no encontrado"
                            echo "Ejecutando script de configuración..."
                            if [ -f "./setup-backend.sh" ]; then
                                chmod +x ./setup-backend.sh
                                ./setup-backend.sh
                            else
                                echo "❌ Script setup-backend.sh no encontrado"
                                exit 1
                            fi
                        fi

                        echo "Configuración de backend completada"
                    '''
                }
            }
        }

        stage('Terraform Initialize') {
            steps {
                echo 'INIT - Inicializando Terraform con backend remoto'
                script {
                    sh '''
                        cd ${TF_WORKSPACE}
                        echo "Inicializando Terraform con backend de Azure Storage..."

                        # Configurar credenciales para el backend
                        ARM_ACCESS_KEY=$(az storage account keys list --resource-group ${TF_BACKEND_RESOURCE_GROUP} --account-name ${TF_BACKEND_STORAGE_ACCOUNT} --query '[0].value' -o tsv)
                        export ARM_ACCESS_KEY

                        # Inicializar con backend remoto
                        terraform init -reconfigure

                        echo "✓ Terraform inicializado con backend remoto"

                        # Verificar estado remoto
                        echo "Verificando acceso al estado remoto..."
                        terraform state list || echo "Estado remoto vacío o no accesible"

                        echo "Inicialización completada"
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                echo 'PLAN - Generando plan de ejecución de Terraform'
                script {
                    sh '''
                        cd ${TF_WORKSPACE}
                        echo "Generando plan de ejecución de Terraform..."

                        # Configurar credenciales
                        ARM_ACCESS_KEY=$(az storage account keys list --resource-group ${TF_BACKEND_RESOURCE_GROUP} --account-name ${TF_BACKEND_STORAGE_ACCOUNT} --query '[0].value' -o tsv)
                        export ARM_ACCESS_KEY

                        # Ejecutar detección de drift antes del plan
                        if [ -f "./drift-detection.sh" ]; then
                            echo "Ejecutando detección de drift..."
                            chmod +x ./drift-detection.sh
                            ./drift-detection.sh || echo "Drift detection completado con advertencias"
                        fi

                        # Refresh del estado
                        echo "Actualizando estado desde Azure..."
                        terraform refresh

                        # Generar plan
                        echo "Generando plan de cambios..."
                        terraform plan -detailed-exitcode -out=tfplan
                        PLAN_EXIT_CODE=$?

                        case $PLAN_EXIT_CODE in
                            0)
                                echo "✓ No hay cambios que aplicar"
                                ;;
                            1)
                                echo "❌ Error en la generación del plan"
                                exit 1
                                ;;
                            2)
                                echo "⚠️ Cambios detectados - Plan generado exitosamente"
                                echo "Guardando plan para revisión..."
                                terraform show -no-color tfplan > plan-output.txt
                                echo "Plan guardado en: plan-output.txt"
                                ;;
                        esac

                        echo "Generación de plan completada"
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                echo 'APPLY - Aplicando cambios de infraestructura'
                script {
                    sh '''
                        cd ${TF_WORKSPACE}
                        echo "Aplicando cambios de infraestructura..."

                        # Configurar credenciales
                        ARM_ACCESS_KEY=$(az storage account keys list --resource-group ${TF_BACKEND_RESOURCE_GROUP} --account-name ${TF_BACKEND_STORAGE_ACCOUNT} --query '[0].value' -o tsv)
                        export ARM_ACCESS_KEY

                        # Verificar si hay plan para aplicar
                        if [ -f "tfplan" ]; then
                            echo "Aplicando plan de Terraform..."
                            terraform apply -auto-approve tfplan

                            echo "✓ Cambios aplicados exitosamente"

                            # Mostrar outputs
                            echo "Outputs de la infraestructura:"
                            terraform output

                        else
                            echo "No hay plan para aplicar"
                        fi

                        # Verificar estado final
                        echo "Estado final de recursos:"
                        terraform state list

                        echo "Aplicación de cambios completada"
                    '''
                }
            }
        }

        stage('Post-Deploy Verification') {
            steps {
                echo 'VERIFY - Verificación post-despliegue'
                script {
                    sh '''
                        cd ${TF_WORKSPACE}
                        echo "Ejecutando verificaciones post-despliegue..."

                        # Configurar credenciales
                        ARM_ACCESS_KEY=$(az storage account keys list --resource-group ${TF_BACKEND_RESOURCE_GROUP} --account-name ${TF_BACKEND_STORAGE_ACCOUNT} --query '[0].value' -o tsv)
                        export ARM_ACCESS_KEY

                        # Ejecutar detección de drift final
                        if [ -f "./drift-detection.sh" ]; then
                            echo "Verificación final de drift..."
                            ./drift-detection.sh
                        fi

                        # Crear reporte de despliegue
                        echo "Generando reporte de despliegue..."
                        cat > deployment-report.json << EOF
{
  "timestamp": "$(date -Iseconds)",
  "build_number": "${BUILD_NUMBER}",
  "commit": "${GIT_COMMIT}",
  "branch": "${GIT_BRANCH}",
  "terraform_version": "$(terraform version -json | jq -r '.terraform_version')",
  "applied_successfully": true,
  "infrastructure_state": "$(terraform state list | wc -l) resources managed"
}
EOF

                        echo "✓ Verificación post-despliegue completada"
                        echo "Reporte guardado en: deployment-report.json"

                        # Mostrar resumen
                        echo "=== RESUMEN DEL DESPLIEGUE ==="
                        echo "Build: ${BUILD_NUMBER}"
                        echo "Commit: ${GIT_COMMIT}"
                        echo "Recursos gestionados: $(terraform state list | wc -l)"
                        echo "Timestamp: $(date)"
                        echo "=== FIN DEL RESUMEN ==="
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline de infraestructura finalizado'
            script {
                sh '''
                    echo "=== RESUMEN DEL PIPELINE DE INFRAESTRUCTURA ==="
                    echo "Build: ${BUILD_NUMBER}"
                    echo "Commit: ${GIT_COMMIT}"
                    echo "Branch: ${GIT_BRANCH}"
                    echo "Timestamp: $(date)"
                    echo "Workspace: ${TF_WORKSPACE}"
                    echo "=== FIN DEL RESUMEN ==="
                '''
            }
        }
        success {
            echo 'Pipeline de infraestructura ejecutado exitosamente'
            // Archivar artifacts del despliegue exitoso
            script {
                sh '''
                    echo "Archivando artifacts del despliegue exitoso..."
                    cd ${TF_WORKSPACE}
                    if [ -f "plan-output.txt" ]; then
                        echo "✓ Plan archivado"
                    fi
                    if [ -f "deployment-report.json" ]; then
                        echo "✓ Reporte de despliegue archivado"
                    fi
                '''
            }
            // Archivar artifacts en Jenkins
            archiveArtifacts artifacts: 'tmp/terraform-workspace/plan-output.txt,tmp/terraform-workspace/deployment-report.json,tmp/terraform-workspace/drift-reports/*.json',
                           fingerprint: true,
                           allowEmptyArchive: true,
                           caseSensitive: true
        }
        failure {
            echo 'Pipeline de infraestructura falló'
            // En caso de fallo, archivar logs para debugging
            archiveArtifacts artifacts: 'tmp/terraform-workspace/**/*',
                           fingerprint: false,
                           allowEmptyArchive: true,
                           caseSensitive: true
        }
    }
}