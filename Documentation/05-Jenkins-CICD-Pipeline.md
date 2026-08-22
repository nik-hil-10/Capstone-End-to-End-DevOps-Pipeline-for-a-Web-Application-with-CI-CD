# 05. End-to-End Jenkins CI/CD Pipeline

## 1. Overview
The Jenkins CI/CD pipeline orchestrates the entire software delivery lifecycle from code commit to production rollout on AWS EKS. The Jenkins Controller runs directly on a dedicated **AWS EC2 instance (`t3.medium`)** in the VPC public subnet (`10.0.1.0/24`) with an Elastic IP and an attached IAM Instance Profile for direct, zero-credential access to Amazon EKS and Amazon ECR. It is implemented as a Declarative Pipeline in `Jenkinsfile`.

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

## 3. Jenkins AWS EC2 Deployment & Configuration

### Provisioning on AWS EC2
* **Compute:** `t3.medium` (Ubuntu 22.04 LTS) provisioned via `terraform/jenkins_ec2.tf`.
* **Networking:** Public Subnet 1 (`10.0.1.0/24`) with dedicated AWS Elastic IP.
* **IAM Instance Profile:** `streaming-platform-jenkins-instance-profile` granting native IAM role permissions for EKS cluster administration, ECR image push, and S3 state access.
* **Security Group:** Inbound Port `8080` (Web UI) and Port `22` (SSH management).

### Required Jenkins Plugins
1.  **Pipeline:** Declarative Pipeline support.
2.  **AWS Credentials Plugin / Amazon Web Services SDK:** For secure IAM credential injection.
3.  **Docker Pipeline & Docker Plugin:** For container building.
4.  **Kubernetes CLI Plugin:** For executing `kubectl` within pipeline stages.
5.  **Git Plugin:** For GitHub SCM integration.
6.  **Slack Notification Plugin:** For real-time incident alerting.
7.  **Prometheus Metrics Plugin:** For exporting Jenkins build metrics to Prometheus.

### Setting Up Credentials in Jenkins
1.  Navigate to **Jenkins Dashboard** -> **Manage Jenkins** -> **Credentials** -> **System** -> **Global credentials**.
2.  **AWS Credentials (ID: `aws-capstone-credentials`):** Optional if using IAM Instance Profile; enter Access Key and Secret Key if using IAM user.
3.  **Slack Webhook Secret Text (ID: `slack-token`):** Enter your Slack Incoming Webhook URL to enable real-time Slack notifications.

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
