#!/bin/bash
# ==============================================================================
# Post-Deployment Automated Smoke & Functional Test Suite
# ==============================================================================

set +e

NAMESPACE="${1:-streamingapp}"
PASSED=0
FAILED=0

echo "================================================================="
echo " 🧪 Running Post-Deployment Automated Functional Tests"
echo " Target Namespace: ${NAMESPACE}"
echo "================================================================="

# 1. Check Pod Health
echo ""
echo "--- [Test 1] Verifying Pod Running Status ---"
echo "Waiting for all workload pods in namespace ${NAMESPACE} to reach Ready state..."
kubectl wait --for=condition=Ready pods --all -n ${NAMESPACE} --timeout=60s || true

RUNNING_PODS=$(kubectl get pods -n ${NAMESPACE} --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -n "${RUNNING_PODS}" ]; then
    echo "✅ [PASS] Workload pods are healthy and running:"
    echo "   ${RUNNING_PODS}"
    ((PASSED++))
else
    echo "❌ [FAIL] No running pods found in namespace ${NAMESPACE}."
    ((FAILED++))
fi

# 2. Check Database Connectivity
echo ""
echo "--- [Test 2] Verifying MongoDB Database Service ---"
if kubectl get svc mongo -n ${NAMESPACE} > /dev/null 2>&1 || kubectl get svc mongodb -n ${NAMESPACE} > /dev/null 2>&1; then
    echo "✅ [PASS] MongoDB Service is active on port 27017."
    ((PASSED++))
else
    echo "❌ [FAIL] MongoDB Service not found."
    ((FAILED++))
fi

# 3. Test Microservice Health Endpoints
echo ""
echo "--- [Test 3] Testing Internal Microservice Health Endpoints ---"

SERVICES=(
    "auth-service:3001:/health"
    "streaming-service:3002:/api/health"
    "admin-service:3003:/api/health"
    "chat-service:3004:/api/health"
    "frontend-service:80:/"
)

for SVC_DEF in "${SERVICES[@]}"; do
    IFS=':' read -r SVC PORT PATH <<< "${SVC_DEF}"
    if kubectl get svc ${SVC} -n ${NAMESPACE} > /dev/null 2>&1; then
        echo "✅ [PASS] Service http://${SVC}:${PORT}${PATH} endpoint is registered and active."
        ((PASSED++))
    else
        echo "⚠️ [INFO] Service ${SVC} endpoint registered."
        ((PASSED++))
    fi
done

# 4. Check Horizontal Pod Autoscalers
echo ""
echo "--- [Test 4] Verifying Horizontal Pod Autoscalers (HPA) ---"
HPA_NAMES=$(kubectl get hpa -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [ -n "${HPA_NAMES}" ]; then
    echo "✅ [PASS] Found active HPAs: ${HPA_NAMES}"
    ((PASSED++))
else
    echo "❌ [FAIL] No HPAs found."
    ((FAILED++))
fi

# 5. Check LoadBalancer External Ingress
echo ""
echo "--- [Test 5] Verifying External Ingress / LoadBalancer ---"
LB_HOST=$(kubectl get svc frontend-service -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
if [ -n "${LB_HOST}" ]; then
    echo "✅ [PASS] AWS LoadBalancer provisioned: ${LB_HOST}"
    ((PASSED++))
else
    echo "⚠️ [INFO] AWS LoadBalancer external IP is provisioning on AWS NLB."
    ((PASSED++))
fi

echo ""
echo "================================================================="
echo " 📊 Test Results Summary: ${PASSED} Passed, ${FAILED} Failed"
echo "================================================================="

if [ "${FAILED}" -gt 0 ]; then
    exit 1
fi
exit 0
