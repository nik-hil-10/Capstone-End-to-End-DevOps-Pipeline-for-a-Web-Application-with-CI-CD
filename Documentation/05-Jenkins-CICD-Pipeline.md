# 05. End-to-End Jenkins CI/CD Pipeline

## 1. Overview
The Jenkins CI/CD pipeline automates the entire software delivery lifecycle from code commit to production rollout on AWS EKS. It is implemented as a Declarative Pipeline in `Jenkinsfile`.

---

## 2. Pipeline Stages Breakdown

```
[ Stage 1: Checkout SCM ]
       │ Pulls latest code, logs commit hash, author, and branch.
       ▼
[ Stage 2: Code Quality & Security Audit ]
       │ Runs npm audit and static syntax validation across microservices.
       ▼
[ Stage 3: Infrastructure as Code (Terraform) ]
       │ Conditional: Runs 'terraform plan' and 'terraform apply' to provision AWS VPC, EKS, and ECR.
       ▼
[ Stage 4: Configuration Management (Ansible) ]
       │ Conditional: Executes Ansible playbooks to ensure build dependencies and tooling are current.
       ▼
[ Stage 5: Build Container Images ]
       │ Builds 5 multi-tier Docker images tagged with the build number (build-${BUILD_NUMBER}) and 'latest'.
       ▼
[ Stage 6: Push Images to Amazon ECR ]
       │ Authenticates with AWS ECR and pushes container images to respective repositories.
       ▼
[ Stage 7: Deploy to Amazon EKS ]
       │ Injects the dynamic build tag and applies Kubernetes manifests to the 'streamingapp' namespace.
       ▼
[ Stage 8: Verification & Health Check ]
       │ Executes 'kubectl rollout status' for each service and asserts pods and services are healthy.
       ▼
[ Post-Action Cleanup ]
       │ Prunes dangling local Docker images and logs success/failure notifications.
```

---

## 3. Jenkins Prerequisites & Configuration

### Required Jenkins Plugins
1.  **Pipeline:** Declarative Pipeline support.
2.  **AWS Credentials Plugin / Amazon Web Services SDK:** For secure IAM credential injection.
3.  **Docker Pipeline & Docker Plugin:** For container building.
4.  **Kubernetes CLI Plugin:** For executing `kubectl` within pipeline stages.
5.  **Git Plugin:** For GitHub SCM integration.

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
