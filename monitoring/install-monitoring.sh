#!/usr/bin/env bash
set -e

echo "================================================================="
echo " Deploying Prometheus & Grafana Monitoring Stack on AWS EKS"
echo "================================================================="

echo "[1/4] Adding Prometheus Community Helm Repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "[2/4] Creating 'monitoring' namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "[3/4] Installing kube-prometheus-stack..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "$SCRIPT_DIR/helm-values-prometheus.yaml"

echo "[4/4] Applying Custom Alerting Rules..."
kubectl apply -f "$SCRIPT_DIR/custom-alerts.yaml"

echo "================================================================="
echo " Monitoring Stack Installed Successfully!"
echo " Access Grafana: kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"
echo " Username: admin | Password: admin-secure-password"
echo "================================================================="
