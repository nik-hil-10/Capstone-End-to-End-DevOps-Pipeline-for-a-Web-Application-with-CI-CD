#!/usr/bin/env bash
set -e

echo "====================================================================="
echo " AWS Resource Teardown and Cost Optimization Script (Linux/Mac)"
echo "====================================================================="
echo "WARNING: This will destroy all AWS resources provisioned by Terraform!"
read -p "Are you sure you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

echo "[1/3] Deleting Kubernetes Load Balancers and Services to avoid dangling AWS ELBs..."
kubectl delete svc --all -n streamingapp --ignore-not-found=true || true

echo "[2/3] Running Terraform Destroy..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
terraform destroy -auto-approve

echo "[3/3] Teardown Complete! All billable AWS resources have been terminated."
