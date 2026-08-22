#!/bin/bash
set -e

echo "====================================================================="
echo " AWS Automated Full Infrastructure Teardown Script (Linux / macOS)"
echo "====================================================================="
echo "WARNING: This will permanently destroy all AWS resources provisioned"
echo "         by Terraform, including EKS, EC2, VPC, ECR, and Load Balancers!"
echo ""

read -p "Are you sure you want to proceed with full teardown? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Teardown cancelled by user."
    exit 0
fi

echo ""
echo "[1/4] Cleaning up Kubernetes Services, LoadBalancers, and PVCs..."
kubectl delete svc --all -n streamingapp --ignore-not-found=true --timeout=60s || true
kubectl delete svc --all -n monitoring --ignore-not-found=true --timeout=60s || true
kubectl delete pvc --all -n streamingapp --ignore-not-found=true --timeout=60s || true
kubectl delete ns streamingapp --ignore-not-found=true --timeout=60s || true
kubectl delete ns monitoring --ignore-not-found=true --timeout=60s || true

echo ""
echo "[2/4] Force-deleting Amazon ECR Repositories and Docker Images..."
aws ecr delete-repository --repository-name "streaming-platform/admin-service" --force --region ap-south-1 2>/dev/null || true
aws ecr delete-repository --repository-name "streaming-platform/auth-service" --force --region ap-south-1 2>/dev/null || true
aws ecr delete-repository --repository-name "streaming-platform/chat-service" --force --region ap-south-1 2>/dev/null || true
aws ecr delete-repository --repository-name "streaming-platform/frontend" --force --region ap-south-1 2>/dev/null || true
aws ecr delete-repository --repository-name "streaming-platform/streaming-service" --force --region ap-south-1 2>/dev/null || true

echo ""
echo "[3/4] Running Terraform Destroy for all AWS Infrastructure..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."
terraform destroy -auto-approve

echo ""
echo "====================================================================="
echo "[4/4] TEARDOWN COMPLETE!"
echo "All AWS EKS, EC2, VPC, ECR, and Networking resources have been"
echo "completely destroyed. AWS billing has been stopped (100% savings)."
echo "====================================================================="
