// =============================================================================
// Jenkins Declarative Pipeline - End-to-End DevOps Lifecycle
// =============================================================================
// Project: End-to-End DevOps Pipeline for a Web Application with CI/CD
// Application: StreamingApp (Auth, Streaming, Admin, Chat, Frontend + MongoDB)
// Architecture: AWS EKS, ECR, VPC, S3 Remote State, Ansible, Prometheus, Grafana
// =============================================================================

pipeline {
    agent any

    // ─────────────────────────────────────────────────────────────────────────
    // Pipeline Triggers: Triggers ONLY on code push (Event-Driven Webhooks)
    // ─────────────────────────────────────────────────────────────────────────
    triggers {
        githubPush()
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['production', 'staging', 'dev'], description: 'Target Deployment Environment')
        booleanParam(name: 'PROVISION_INFRASTRUCTURE', defaultValue: true, description: 'Run Stage 2 (Terraform) & Stage 3 (Ansible)')
        booleanParam(name: 'SETUP_MONITORING', defaultValue: true, description: 'Deploy/Update Prometheus & Grafana Monitoring in Stage 5')
        booleanParam(name: 'DESTROY_INFRASTRUCTURE', defaultValue: false, description: 'DANGER: Destroy all AWS cloud infrastructure')
    }

    environment {
        AWS_REGION         = 'ap-south-1'
        AWS_CREDENTIALS_ID = 'aws-capstone-credentials'
        EKS_CLUSTER_NAME   = 'streaming-eks-cluster'
        K8S_NAMESPACE      = 'streamingapp'
        PROJECT_PREFIX     = 'streaming-platform'
        IMAGE_TAG          = "build-${BUILD_NUMBER}"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {

        // =====================================================================
        // STAGE 1: Build Stage
        // Triggers on code push, builds all Docker images, and pushes to AWS ECR
        // =====================================================================
        stage('Build Stage') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 1] Build Stage: Building Docker Images & Pushing to AWS ECR"
                echo " Tag: ${IMAGE_TAG} | Commit: ${env.GIT_COMMIT?.take(7) ?: 'Manual'}"
                echo "================================================================="
                dir('StreamingApp') {
                    sh '''
                        echo "=== 1.1 Static Analysis & Dependency Vulnerability Audits ==="
                        cd backend/authService && npm audit --audit-level=critical || true
                        cd ../streamingService && npm audit --audit-level=critical || true
                        cd ../adminService && npm audit --audit-level=critical || true
                        cd ../chatService && npm audit --audit-level=critical || true
                        cd ../..

                        echo "=== 1.2 Building Multi-Tier Docker Images ==="
                        docker build -t ${PROJECT_PREFIX}/auth-service:${IMAGE_TAG} -t ${PROJECT_PREFIX}/auth-service:latest backend/authService
                        docker build -t ${PROJECT_PREFIX}/streaming-service:${IMAGE_TAG} -t ${PROJECT_PREFIX}/streaming-service:latest backend/streamingService
                        docker build -t ${PROJECT_PREFIX}/admin-service:${IMAGE_TAG} -t ${PROJECT_PREFIX}/admin-service:latest backend/adminService
                        docker build -t ${PROJECT_PREFIX}/chat-service:${IMAGE_TAG} -t ${PROJECT_PREFIX}/chat-service:latest backend/chatService
                        docker build -t ${PROJECT_PREFIX}/frontend:${IMAGE_TAG} -t ${PROJECT_PREFIX}/frontend:latest frontend

                        echo "=== 1.3 Authenticating & Pushing Images to Amazon ECR ==="
                        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        
                        echo "Logging into Amazon ECR: ${ECR_REGISTRY}..."
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

        // =====================================================================
        // STAGE 2: Infrastructure Provisioning Stage
        // Runs Terraform scripts (VPC, EKS, EC2) on AWS with S3 Remote State
        // =====================================================================
        stage('Infrastructure Provisioning Stage') {
            when {
                expression { return params.PROVISION_INFRASTRUCTURE == true && params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 2] Infrastructure Provisioning Stage: Terraform (VPC, EKS, EC2)"
                echo " State Store: AWS S3 + DynamoDB Locking | Target: ${params.ENVIRONMENT}"
                echo "================================================================="
                dir('terraform') {
                    sh '''
                        terraform init -no-color
                        terraform validate -no-color
                        terraform plan -var="environment=${ENVIRONMENT}" -out=tfplan -no-color
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }

        // =====================================================================
        // STAGE 3: Configuration Management Stage
        // Runs Ansible playbooks to configure instances and Kubernetes nodes
        // =====================================================================
        stage('Configuration Management Stage') {
            when {
                expression { return params.PROVISION_INFRASTRUCTURE == true && params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 3] Configuration Management Stage: Ansible Node & Tool Setup"
                echo "================================================================="
                dir('ansible') {
                    sh '''
                        ansible-playbook -i inventory/hosts.ini playbooks/setup_tools.yml --connection=local
                        ansible-playbook -i inventory/hosts.ini playbooks/configure_jenkins_agent.yml --connection=local
                    '''
                }
            }
        }

        // =====================================================================
        // STAGE 4: Deployment Stage
        // Deploys application to AWS EKS with LoadBalancers, HPA, and Health Probes
        // =====================================================================
        stage('Deployment Stage') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 4] Deployment Stage: Deploying Manifests to Kubernetes (EKS)"
                echo "================================================================="
                sh '''
                    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                    echo "Connecting to EKS Cluster: ${EKS_CLUSTER_NAME}..."
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}

                    echo "Applying Namespaces, ConfigMaps, and Persistent Datastores..."
                    kubectl apply -f k8s/00-namespace.yaml
                    kubectl apply -f k8s/01-configmaps-secrets.yaml
                    kubectl apply -f k8s/02-mongodb.yaml

                    echo "Deploying Microservices with Image Tag: ${IMAGE_TAG}..."
                    sed "s|REPLACED_BY_IMAGE_TAG|${ECR_REGISTRY}/${PROJECT_PREFIX}/auth-service:${IMAGE_TAG}|g" k8s/03-auth-service.yaml | kubectl apply -f -
                    sed "s|REPLACED_BY_IMAGE_TAG|${ECR_REGISTRY}/${PROJECT_PREFIX}/streaming-service:${IMAGE_TAG}|g" k8s/04-streaming-service.yaml | kubectl apply -f -
                    sed "s|REPLACED_BY_IMAGE_TAG|${ECR_REGISTRY}/${PROJECT_PREFIX}/admin-service:${IMAGE_TAG}|g" k8s/05-admin-service.yaml | kubectl apply -f -
                    sed "s|REPLACED_BY_IMAGE_TAG|${ECR_REGISTRY}/${PROJECT_PREFIX}/chat-service:${IMAGE_TAG}|g" k8s/06-chat-service.yaml | kubectl apply -f -
                    sed "s|REPLACED_BY_IMAGE_TAG|${ECR_REGISTRY}/${PROJECT_PREFIX}/frontend:${IMAGE_TAG}|g" k8s/07-frontend.yaml | kubectl apply -f -

                    echo "Configuring Horizontal Pod Autoscalers (HPA)..."
                    kubectl apply -f k8s/09-hpa.yaml

                    echo "Verifying Rollout Status across all deployments..."
                    kubectl rollout status deployment/auth-service -n ${K8S_NAMESPACE} --timeout=180s
                    kubectl rollout status deployment/streaming-service -n ${K8S_NAMESPACE} --timeout=180s
                    kubectl rollout status deployment/admin-service -n ${K8S_NAMESPACE} --timeout=180s
                    kubectl rollout status deployment/chat-service -n ${K8S_NAMESPACE} --timeout=180s
                    kubectl rollout status deployment/frontend -n ${K8S_NAMESPACE} --timeout=180s
                '''
            }
        }

        // =====================================================================
        // STAGE 5: Testing and Monitoring Stage
        // Runs automated test scripts & sets up Prometheus, Grafana, and Alerts
        // =====================================================================
        stage('Testing and Monitoring Stage') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "================================================================="
                echo " [Stage 5] Testing & Monitoring Stage: Smoke Tests & Observability"
                echo "================================================================="
                sh '''
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}

                    echo "=== 5.1 Running Automated Post-Deployment Functional Smoke Tests ==="
                    chmod +x tests/smoke-test.sh
                    ./tests/smoke-test.sh ${K8S_NAMESPACE}

                    echo "=== 5.2 Provisioning Prometheus & Grafana Monitoring Stack ==="
                    if [ "${SETUP_MONITORING}" = "true" ]; then
                        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
                        helm repo update
                        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
                        helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
                            --namespace monitoring \
                            --values monitoring/helm-values-prometheus.yaml
                        kubectl apply -f monitoring/custom-alerts.yaml
                        echo "Prometheus and Grafana alerting configured."
                    fi

                    echo "=== 5.3 Active LoadBalancers & Service Endpoints ==="
                    kubectl get svc -n ${K8S_NAMESPACE}
                    kubectl get svc -n monitoring
                '''
            }
        }

        // =====================================================================
        // OPTIONAL TEARDOWN: Clean up AWS Infrastructure when explicitly triggered
        // =====================================================================
        stage('Infrastructure Teardown (On-Demand)') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == true }
            }
            steps {
                echo "================================================================="
                echo " [Teardown] Destroying AWS Infrastructure"
                echo "================================================================="
                sh '''
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} || true
                    kubectl delete svc --all -n ${K8S_NAMESPACE} --ignore-not-found=true || true
                    kubectl delete namespace ${K8S_NAMESPACE} --ignore-not-found=true || true
                    kubectl delete namespace monitoring --ignore-not-found=true || true
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

    post {
        always {
            echo "Pipeline Execution Completed. Cleaning up temporary artifacts..."
            sh 'docker image prune -f || true'
        }
        success {
            echo "🎉 CI/CD Pipeline Execution SUCCEEDED! All 5 Stages Completed."
            withCredentials([string(credentialsId: 'slack-token', variable: 'SLACK_WEBHOOK')]) {
                sh '''
                    if [ -n "$SLACK_WEBHOOK" ]; then
                        printf '{"text":"✅ *Pipeline SUCCESS* - `streaming-platform-pipeline` #%s\\n*Status:* All 5 Stages Passed\\n<http://13.207.80.105:8080/job/streaming-platform-pipeline/%s/|View Build>"}\n' "${BUILD_NUMBER}" "${BUILD_NUMBER}" > /tmp/slack_msg.json
                        curl -s -X POST -H "Content-type: application/json" -d @/tmp/slack_msg.json "$SLACK_WEBHOOK" || true
                        rm -f /tmp/slack_msg.json
                    fi
                '''
            }
        }
        failure {
            echo "❌ CI/CD Pipeline Execution FAILED! Please inspect stage logs."
            withCredentials([string(credentialsId: 'slack-token', variable: 'SLACK_WEBHOOK')]) {
                sh '''
                    if [ -n "$SLACK_WEBHOOK" ]; then
                        printf '{"text":"🚨 *Pipeline FAILED* - `streaming-platform-pipeline` #%s\\n*Status:* Inspect Console Logs\\n<http://13.207.80.105:8080/job/streaming-platform-pipeline/%s/console|View Console Logs>"}\n' "${BUILD_NUMBER}" "${BUILD_NUMBER}" > /tmp/slack_msg.json
                        curl -s -X POST -H "Content-type: application/json" -d @/tmp/slack_msg.json "$SLACK_WEBHOOK" || true
                        rm -f /tmp/slack_msg.json
                    fi
                '''
            }
        }
    }
}
