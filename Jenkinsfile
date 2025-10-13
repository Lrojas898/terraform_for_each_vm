pipeline {
    agent any

    triggers {
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
        skipDefaultCheckout(true)
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        TF_WORKSPACE = "${env.WORKSPACE}/terraform-workspace"
        TF_VAR_subscription_id = '44127b49-3951-4881-8cf2-9cff7a88e6ca' // RECOMENDACIÓN: Usar credenciales de Jenkins
        TERRAFORM_REPO = 'https://github.com/Lrojas898/terraform_for_each_vm.git'
        TF_BACKEND_RESOURCE_GROUP = 'devops-terraform-state-rg'
        TF_BACKEND_STORAGE_ACCOUNT = 'devopsterraformstate001'
        TF_BACKEND_CONTAINER = 'tfstate'
        TF_BACKEND_KEY = 'devops-infrastructure.tfstate'
        ARM_ACCESS_KEY_FILE = "${env.WORKSPACE}/arm_access_key"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'CHECKOUT - Obteniendo código del repositorio terraform_for_each_vm'
                script {
                    checkout([$class: 'GitSCM',
                        branches: [[name: '*/main']],
                        userRemoteConfigs: [[url: env.TERRAFORM_REPO]]
                    ])

                    sh '''
                        echo "Conectando al repositorio Git: ${TERRAFORM_REPO}"
                        echo "Rama: main"
                        echo "Commit actual: ${GIT_COMMIT}"

                        # Limpiar y crear workspace de Terraform
                        rm -rf ${TF_WORKSPACE}
                        mkdir -p ${TF_WORKSPACE}

                        # Copiar archivos del repositorio, excluyendo el directorio de destino
                        echo "Copiando archivos de Terraform..."
                        find . -maxdepth 1 -mindepth 1 -not -name "terraform-workspace" -exec cp -r {} "${TF_WORKSPACE}/" \\;

                        echo "Archivos disponibles en workspace de Terraform:"
                        ls -la ${TF_WORKSPACE}/
                    '''
                }
            }
        }

        stage('Terraform Setup & Validate') {
            steps {
                dir(env.TF_WORKSPACE) {
                    echo 'VALIDATE - Validando sintaxis y formato de archivos Terraform'
                    script {
                        sh '''
                            echo "Instalando Terraform si es necesario..."
                            if ! command -v terraform &> /dev/null; then
                                wget -q https://releases.hashicorp.com/terraform/1.6.2/terraform_1.6.2_linux_amd64.zip
                                unzip -q terraform_1.6.2_linux_amd64.zip
                                chmod +x terraform
                                export PATH=$(pwd):$PATH
                            fi
                            terraform version

                            echo "Validando configuración de Terraform..."
                            terraform init -backend=false
                            terraform validate

                            echo "Verificando formato de archivos Terraform..."
                            if ! terraform fmt -check -recursive; then
                                echo "⚠️ Archivos con formato incorrecto detectados. Aplicando formato..."
                                terraform fmt -recursive
                            else
                                echo "✓ Todos los archivos tienen formato correcto"
                            fi
                        '''
                    }
                }
            }
        }

        stage('Setup Azure Backend') {
            steps {
                dir(env.TF_WORKSPACE) {
                    echo 'BACKEND - Configurando backend de Azure Storage'
                    script {
                        sh '''
                            echo "Instalando Azure CLI si es necesario..."
                            if ! command -v az &> /dev/null; then
                                curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
                            fi

                            echo "Verificando Azure Storage Backend..."
                            if az storage account show --name ${TF_BACKEND_STORAGE_ACCOUNT} --resource-group ${TF_BACKEND_RESOURCE_GROUP} &> /dev/null; then
                                echo "✓ Azure Storage Backend disponible. Obteniendo credenciales..."
                                az storage account keys list --resource-group ${TF_BACKEND_RESOURCE_GROUP} --account-name ${TF_BACKEND_STORAGE_ACCOUNT} --query '[0].value' -o tsv > ${ARM_ACCESS_KEY_FILE}
                                echo "✓ Credenciales de Azure Storage guardadas"
                            else
                                echo "⚠️ Azure Storage Backend no encontrado. Ejecutando script de configuración..."
                                if [ -f "./setup-backend.sh" ]; then
                                    chmod +x ./setup-backend.sh
                                    ./setup-backend.sh
                                    # Re-intentar obtener la clave después de crear el backend
                                    az storage account keys list --resource-group ${TF_BACKEND_RESOURCE_GROUP} --account-name ${TF_BACKEND_STORAGE_ACCOUNT} --query '[0].value' -o tsv > ${ARM_ACCESS_KEY_FILE}
                                else
                                    echo "❌ Script setup-backend.sh no encontrado"
                                    exit 1
                                fi
                            fi
                        '''
                    }
                }
            }
        }

        stage('Terraform Initialize') {
            steps {
                dir(env.TF_WORKSPACE) {
                    echo 'INIT - Inicializando Terraform con backend remoto'
                    script {
                        sh '''
                            export ARM_ACCESS_KEY=$(cat ${ARM_ACCESS_KEY_FILE})
                            if [ -z "$ARM_ACCESS_KEY" ]; then
                                echo "❌ No se pudo obtener la ARM_ACCESS_KEY."
                                exit 1
                            fi

                            echo "Inicializando Terraform con backend de Azure Storage..."
                            terraform init -reconfigure

                            echo "✓ Terraform inicializado con backend remoto"
                            terraform state list || echo "Estado remoto vacío o no accesible"
                        '''
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir(env.TF_WORKSPACE) {
                    echo 'PLAN - Generando plan de ejecución de Terraform'
                    script {
                        sh '''
                            export ARM_ACCESS_KEY=$(cat ${ARM_ACCESS_KEY_FILE})
                            
                            if [ -f "./drift-detection.sh" ]; then
                                echo "Ejecutando detección de drift..."
                                chmod +x ./drift-detection.sh
                                ./drift-detection.sh || echo "Detección de drift completada con advertencias"
                            fi

                            echo "Actualizando estado desde Azure y generando plan..."
                            terraform refresh
                            terraform plan -detailed-exitcode -out=tfplan
                            PLAN_EXIT_CODE=$?

                            case $PLAN_EXIT_CODE in
                                0) echo "✓ No hay cambios que aplicar" ;;
                                1) echo "❌ Error en la generación del plan"; exit 1 ;;
                                2) 
                                  echo "⚠️ Cambios detectados - Plan generado exitosamente"
                                  terraform show -no-color tfplan > plan-output.txt
                                  echo "Plan guardado en: plan-output.txt"
                                  ;;
                            esac
                        '''
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir(env.TF_WORKSPACE) {
                    echo 'APPLY - Aplicando cambios de infraestructura'
                    script {
                        sh '''
                            if [ -f "tfplan" ]; then
                                export ARM_ACCESS_KEY=$(cat ${ARM_ACCESS_KEY_FILE})
                                echo "Aplicando plan de Terraform..."
                                terraform apply -auto-approve tfplan
                                echo "✓ Cambios aplicados exitosamente"
                                
                                echo "Outputs de la infraestructura:"
                                terraform output
                            else
                                echo "No hay plan para aplicar"
                            fi
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline de infraestructura finalizado'
            script {
                // Limpiar archivo de credenciales
                sh 'rm -f ${ARM_ACCESS_KEY_FILE}'
            }
        }
        success {
            echo 'Pipeline ejecutado exitosamente. Archivando artefactos...'
            archiveArtifacts artifacts: 'terraform-workspace/plan-output.txt, terraform-workspace/deployment-report.json', 
                           allowEmptyArchive: true
        }
        failure {
            echo 'Pipeline falló. Archivando logs para depuración...'
            archiveArtifacts artifacts: 'terraform-workspace/**/*', 
                           allowEmptyArchive: true
        }
    }
}