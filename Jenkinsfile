pipeline {
    agent any

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['production', 'staging', 'dev'], description: 'Target Deployment Environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Run Terraform Apply to provision or update AWS EKS/VPC infrastructure')
        booleanParam(name: 'DESTROY_INFRASTRUCTURE', defaultValue: false, description: 'DANGER: Run Terraform Destroy to tear down all cloud infrastructure')
    }

    environment {
        AWS_REGION         = 'ap-south-1'
        AWS_CREDENTIALS_ID = 'aws-capstone-credentials'
        EKS_CLUSTER_NAME   = 'streaming-eks-cluster'
        K8S_NAMESPACE      = 'streamingapp'
        PROJECT_PREFIX     = 'streaming-platform'
        IMAGE_TAG          = "build-${BUILD_NUMBER}"
        // ECR Account ID is fetched dynamically during pipeline execution
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout SCM') {
            steps {
                echo "================================================================="
                echo " [Stage 1] Checking out source repository: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                echo "================================================================="
                checkout scm
                sh '''
                    git log -1 --pretty=format:"Commit: %h | Author: %an | Date: %ad | Message: %s"
                '''
            }
        }

        stage('Code Quality & Security Scan') {
            steps {
                echo "================================================================="
                echo " [Stage 2] Running Static Analysis & Dependency Vulnerability Audits"
                echo "================================================================="
                dir('StreamingApp') {
                    sh '''
                        echo "Validating Node.js microservice configurations..."
                        cd backend/authService && npm audit --audit-level=critical || true
                        cd ../streamingService && npm audit --audit-level=critical || true
                        cd ../adminService && npm audit --audit-level=critical || true
                        cd ../chatService && npm audit --audit-level=critical || true
                    '''
                }
            }
        }

        stage('Infrastructure as Code (Terraform)') {
            when {
                expression { return params.APPLY_TERRAFORM == true && params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 3] Provisioning / Updating AWS Cloud Infrastructure"
                echo "================================================================="
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: env.AWS_CREDENTIALS_ID
                ]]) {
                    dir('terraform') {
                        sh """
                            terraform init -no-color
                            terraform validate -no-color
                            terraform plan -var="environment=${params.ENVIRONMENT}" -out=tfplan -no-color
                            terraform apply -auto-approve tfplan
                        """
                    }
                }
            }
        }

        stage('Configuration Management (Ansible)') {
            when {
                expression { return params.APPLY_TERRAFORM == true && params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 4] Enforcing Host Tooling & Configurations with Ansible"
                echo "================================================================="
                dir('ansible') {
                    sh '''
                        ansible-playbook -i inventory/hosts.ini playbooks/setup_tools.yml --connection=local
                        ansible-playbook -i inventory/hosts.ini playbooks/configure_jenkins_agent.yml --connection=local
                    '''
                }
            }
        }

        stage('Build Container Images') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 5] Building Multi-Tier Docker Images: Tag = ${IMAGE_TAG}"
                echo "================================================================="
                dir('StreamingApp') {
                    sh '''
                        echo "Building Auth Service..."
                        docker build -t ${PROJECT_PREFIX}/auth-service:${IMAGE_TAG} -t ${PROJECT_PREFIX}/auth-service:latest backend/authService

                        echo "Building Streaming Service..."
                        docker build -t ${PROJECT_PREFIX}/streaming-service:${IMAGE_TAG} -t ${PROJECT_PREFIX}/streaming-service:latest backend/streamingService

                        echo "Building Admin Service..."
                        docker build -t ${PROJECT_PREFIX}/admin-service:${IMAGE_TAG} -t ${PROJECT_PREFIX}/admin-service:latest backend/adminService

                        echo "Building Chat Service..."
                        docker build -t ${PROJECT_PREFIX}/chat-service:${IMAGE_TAG} -t ${PROJECT_PREFIX}/chat-service:latest backend/chatService

                        echo "Building Frontend Service..."
                        docker build -t ${PROJECT_PREFIX}/frontend:${IMAGE_TAG} -t ${PROJECT_PREFIX}/frontend:latest frontend
                    '''
                }
            }
        }

        stage('Push Images to Amazon ECR') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 6] Authenticating and Pushing Images to Amazon ECR"
                echo "================================================================="
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: env.AWS_CREDENTIALS_ID
                ]]) {
                    sh '''
                        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        
                        echo "Logging into Amazon ECR registry: ${ECR_REGISTRY}..."
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                        SERVICES="auth-service streaming-service admin-service chat-service frontend"
                        for SVC in $SERVICES; do
                            echo "Pushing ${SVC} (${IMAGE_TAG})..."
                            docker tag ${PROJECT_PREFIX}/${SVC}:${IMAGE_TAG} ${ECR_REGISTRY}/${PROJECT_PREFIX}/${SVC}:${IMAGE_TAG}
                            docker tag ${PROJECT_PREFIX}/${SVC}:latest ${ECR_REGISTRY}/${PROJECT_PREFIX}/${SVC}:latest
                            docker push ${ECR_REGISTRY}/${PROJECT_PREFIX}/${SVC}:${IMAGE_TAG}
                            docker push ${ECR_REGISTRY}/${PROJECT_PREFIX}/${SVC}:latest
                        done
                    '''
                }
            }
        }

        stage('Deploy to Amazon EKS') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 7] Deploying Microservices to Kubernetes (EKS)"
                echo "================================================================="
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: env.AWS_CREDENTIALS_ID
                ]]) {
                    sh '''
                        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                        echo "Updating local kubeconfig for EKS Cluster: ${EKS_CLUSTER_NAME}..."
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}

                        echo "Ensuring Namespace and Core Configs exist..."
                        kubectl apply -f k8s/00-namespace.yaml
                        kubectl apply -f k8s/01-configmaps-secrets.yaml
                        kubectl apply -f k8s/02-mongodb.yaml

                        echo "Applying microservice deployments with image tag: ${IMAGE_TAG}..."
                        sed "s|REPLACED_BY_IMAGE_TAG|${ECR_REGISTRY}/${PROJECT_PREFIX}/auth-service:${IMAGE_TAG}|g" k8s/03-auth-service.yaml | kubectl apply -f -
                        sed "s|REPLACED_BY_IMAGE_TAG|${ECR_REGISTRY}/${PROJECT_PREFIX}/streaming-service:${IMAGE_TAG}|g" k8s/04-streaming-service.yaml | kubectl apply -f -
                        sed "s|REPLACED_BY_IMAGE_TAG|${ECR_REGISTRY}/${PROJECT_PREFIX}/admin-service:${IMAGE_TAG}|g" k8s/05-admin-service.yaml | kubectl apply -f -
                        sed "s|REPLACED_BY_IMAGE_TAG|${ECR_REGISTRY}/${PROJECT_PREFIX}/chat-service:${IMAGE_TAG}|g" k8s/06-chat-service.yaml | kubectl apply -f -
                        sed "s|REPLACED_BY_IMAGE_TAG|${ECR_REGISTRY}/${PROJECT_PREFIX}/frontend:${IMAGE_TAG}|g" k8s/07-frontend.yaml | kubectl apply -f -

                        kubectl apply -f k8s/09-hpa.yaml
                    '''
                }
            }
        }

        stage('Verification & Health Check') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 8] Verifying Deployment Rollout & Microservice Health"
                echo "================================================================="
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: env.AWS_CREDENTIALS_ID
                ]]) {
                    sh '''
                        echo "Checking rollout status for all deployments..."
                        kubectl rollout status deployment/auth-service -n ${K8S_NAMESPACE} --timeout=180s
                        kubectl rollout status deployment/streaming-service -n ${K8S_NAMESPACE} --timeout=180s
                        kubectl rollout status deployment/admin-service -n ${K8S_NAMESPACE} --timeout=180s
                        kubectl rollout status deployment/chat-service -n ${K8S_NAMESPACE} --timeout=180s
                        kubectl rollout status deployment/frontend -n ${K8S_NAMESPACE} --timeout=180s

                        echo "=== Cluster Pod Status ==="
                        kubectl get pods -n ${K8S_NAMESPACE} -o wide

                        echo "=== Cluster Services / Load Balancers ==="
                        kubectl get svc -n ${K8S_NAMESPACE}
                    '''
                }
            }
        }

        stage('Infrastructure Teardown (On-Demand)') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == true }
            }
            steps {
                echo "================================================================="
                echo " [Stage 9] TEARDOWN: Destroying AWS Infrastructure"
                echo "================================================================="
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: env.AWS_CREDENTIALS_ID
                ]]) {
                    sh '''
                        echo "Cleaning up Kubernetes LoadBalancers first..."
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} || true
                        kubectl delete svc --all -n ${K8S_NAMESPACE} --ignore-not-found=true || true
                    '''
                    dir('terraform') {
                        sh '''
                            terraform init -no-color
                            terraform destroy -auto-approve -no-color
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            echo "================================================================="
            echo " Pipeline Execution Completed. Cleaning up temporary artifacts..."
            echo "================================================================="
            sh '''
                docker image prune -f || true
            '''
        }
        success {
            echo "🎉 CI/CD Pipeline Execution SUCCEEDED! All services deployed and verified on EKS."
            script {
                try {
                    slackSend(
                        channel: '#devops-alerts',
                        color: 'good',
                        message: "✅ *Pipeline SUCCESS* - `${env.JOB_NAME}` #${env.BUILD_NUMBER}\n*Environment:* ${params.ENVIRONMENT}\n*Commit:* ${env.GIT_COMMIT?.take(7) ?: 'N/A'}\n<${env.BUILD_URL}|View Build>"
                    )
                } catch (Exception e) {
                    echo "Slack notification skipped: " + e.getMessage()
                }
            }
        }
        failure {
            echo "❌ CI/CD Pipeline Execution FAILED! Please inspect stage logs above."
            script {
                try {
                    slackSend(
                        channel: '#devops-critical',
                        color: 'danger',
                        message: "🚨 *Pipeline FAILED* - `${env.JOB_NAME}` #${env.BUILD_NUMBER}\n*Environment:* ${params.ENVIRONMENT}\n*Stage:* ${env.STAGE_NAME ?: 'Unknown'}\n<${env.BUILD_URL}console|View Console Logs>"
                    )
                } catch (Exception e) {
                    echo "Slack notification skipped: " + e.getMessage()
                }
            }
        }
    }
}
