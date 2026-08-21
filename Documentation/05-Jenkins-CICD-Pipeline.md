# 05. End-to-End Jenkins CI/CD Pipeline

## 1. Overview
The Jenkins CI/CD pipeline automates the entire software delivery lifecycle from code commit to production rollout on AWS EKS. It is implemented as a Declarative Pipeline in `Jenkinsfile`.

---

## 2. Pipeline Stages Breakdown (5 Canonical Stages)

```
[ Stage 1: Build Stage (Triggered on Code Push) ]
       │ • Security scan & dependency audit (npm audit)
       │ • Builds 5 multi-tier Docker images (build-${BUILD_NUMBER} & latest)
       │ • Authenticates with AWS ECR and pushes container images
       ▼
[ Stage 2: Infrastructure Provisioning Stage ]
       │ • Runs 'terraform plan' and 'terraform apply' to provision AWS VPC, EKS, and ECR
       │ • Stores state securely in AWS S3 with DynamoDB locking
       ▼
[ Stage 3: Configuration Management Stage ]
       │ • Executes Ansible playbooks (setup_tools.yml, configure_jenkins_agent.yml)
       │ • Configures EC2 instances and validates tooling idempotency
       ▼
[ Stage 4: Deployment Stage ]
       │ • Injects dynamic build tags and deploys Kubernetes manifests to AWS EKS
       │ • Configures LoadBalancers, HPA autoscaling, and zero-downtime RollingUpdates
       │ • Enforces 'kubectl rollout status' checks
       ▼
[ Stage 5: Testing and Monitoring Stage ]
       │ • Runs automated post-deployment smoke test suite (tests/smoke-test.sh)
       │ • Provisions Prometheus & Grafana monitoring stack via Helm
       │ • Configures Alertmanager and PrometheusRule alerting
       ▼
[ Post-Actions: Notifications & Cleanup ]
       │ • Sends real-time build status alerts to Slack (#devops-alerts / #devops-critical)
       │ • Prunes dangling container artifacts
```

---

## 3. Jenkins Prerequisites & Configuration

### Required Jenkins Plugins
1.  **Pipeline:** Declarative Pipeline support.
2.  **AWS Credentials Plugin / Amazon Web Services SDK:** For secure IAM credential injection.
3.  **Docker Pipeline & Docker Plugin:** For container building.
4.  **Kubernetes CLI Plugin:** For executing `kubectl` within pipeline stages.
5.  **Git Plugin:** For GitHub SCM integration.
6.  **Slack Notification Plugin:** For real-time incident alerting.
7.  **Prometheus Metrics Plugin:** For exporting Jenkins build metrics to Prometheus.

### Setting Up AWS Credentials in Jenkins
1.  Navigate to **Jenkins Dashboard** -> **Manage Jenkins** -> **Credentials** -> **System** -> **Global credentials**.
2.  Click **Add Credentials**.
3.  **Kind:** `AWS Credentials`
4.  **ID:** `aws-capstone-credentials`
5.  **Access Key ID:** Enter your AWS IAM Access Key.
6.  **Secret Access Key:** Enter your AWS IAM Secret Key.
7.  Click **Create**.

---

## 4. Pipeline Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `ENVIRONMENT` | Choice | `production` | Target deployment environment (`production`, `staging`, `dev`). |
| `APPLY_TERRAFORM` | Boolean | `false` | When checked, runs Terraform to provision/update AWS infrastructure. |
| `DESTROY_INFRASTRUCTURE` | Boolean | `false` | **Teardown switch:** When checked, executes `terraform destroy` to eliminate all cloud costs. |

---

## 5. Automated GitHub Webhook Trigger
1.  In your GitHub repository, go to **Settings** -> **Webhooks** -> **Add webhook**.
2.  **Payload URL:** `http://<JENKINS_HOST>:8080/github-webhook/`
3.  **Content type:** `application/json`
4.  **Events:** Select *Just the push event*.
5.  Click **Add webhook**. Any git push will now automatically trigger a full build and deployment!
