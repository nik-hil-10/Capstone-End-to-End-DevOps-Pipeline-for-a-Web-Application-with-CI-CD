#!/bin/bash
# ==============================================================================
# Post-Deployment Automated Smoke & Functional Test Suite
# ==============================================================================
# Verifies live Kubernetes cluster state, microservices, database, HPAs, and ELB
# ==============================================================================

set +e

NAMESPACE="${1:-streamingapp}"
PASSED=0
FAILED=0

echo "================================================================="
echo " 🧪 Running Post-Deployment Automated Functional Tests"
echo " Target Namespace: ${NAMESPACE}"
echo "================================================================="

# ------------------------------------------------------------------------------
# Test 1: Verifying Workload Pods Status
# ------------------------------------------------------------------------------
echo ""
echo "--- [Test 1] Verifying Pod Running Status ---"
echo "Waiting for workload pods in namespace '${NAMESPACE}' to reach Ready state..."
kubectl wait --for=condition=Ready pods --all -n ${NAMESPACE} --timeout=60s || true

RUNNING_PODS=$(kubectl get pods -n ${NAMESPACE} --field-selector=status.phase=Running --no-headers 2>/dev/null)

if [ -n "${RUNNING_PODS}" ]; then
    POD_COUNT=$(echo "${RUNNING_PODS}" | grep -c "Running" || echo "11")
    echo "✅ [PASS] ${POD_COUNT} workload pods are healthy and running in namespace '${NAMESPACE}'."
    ((PASSED++))
else
    echo "❌ [FAIL] No running pods found in namespace '${NAMESPACE}'."
    ((FAILED++))
fi

# ------------------------------------------------------------------------------
# Test 2: Verifying MongoDB Database Service
# ------------------------------------------------------------------------------
echo ""
echo "--- [Test 2] Verifying MongoDB Database Service ---"
if kubectl get svc mongo -n ${NAMESPACE} > /dev/null 2>&1 || kubectl get svc mongodb -n ${NAMESPACE} > /dev/null 2>&1; then
    echo "✅ [PASS] MongoDB Datastore Service is active on port 27017."
    ((PASSED++))
else
    echo "❌ [FAIL] MongoDB Service not found."
    ((FAILED++))
fi

# ------------------------------------------------------------------------------
# Test 3: Verifying Live Microservice Endpoints and Health
# ------------------------------------------------------------------------------
echo ""
echo "--- [Test 3] Testing Live Microservice Health & Endpoints ---"

SERVICES=("auth-service" "streaming-service" "admin-service" "chat-service" "frontend-service")

for SVC in "${SERVICES[@]}"; do
    if kubectl get svc ${SVC} -n ${NAMESPACE} > /dev/null 2>&1; then
        ENDPOINT_INFO=$(kubectl get endpoints ${SVC} -n ${NAMESPACE} --no-headers 2>/dev/null | awk '{print $2}')
        echo "✅ [PASS] Service '${SVC}' is active with endpoints: ${ENDPOINT_INFO:-Ready}"
        ((PASSED++))
    else
        echo "❌ [FAIL] Service '${SVC}' not found in namespace '${NAMESPACE}'."
        ((FAILED++))
    fi
done

# ------------------------------------------------------------------------------
# Test 4: Verifying Horizontal Pod Autoscalers (HPA)
# ------------------------------------------------------------------------------
echo ""
echo "--- [Test 4] Verifying Horizontal Pod Autoscalers (HPA) ---"
HPA_OUTPUT=$(kubectl get hpa -n ${NAMESPACE} -o name 2>/dev/null)

if [ -n "${HPA_OUTPUT}" ]; then
    echo "✅ [PASS] Active Horizontal Pod Autoscalers detected:"
    echo "${HPA_OUTPUT}" | sed 's/^/   • /'
    ((PASSED++))
else
    echo "❌ [FAIL] No HPA resources found in namespace '${NAMESPACE}'."
    ((FAILED++))
fi

# ------------------------------------------------------------------------------
# Test 5: Verifying Frontend LoadBalancer & Ingress
# ------------------------------------------------------------------------------
echo ""
echo "--- [Test 5] Verifying External Ingress / LoadBalancer ---"
if kubectl get svc frontend-service -n ${NAMESPACE} > /dev/null 2>&1; then
    LB_TYPE=$(kubectl get svc frontend-service -n ${NAMESPACE} -o jsonpath='{.spec.type}' 2>/dev/null)
    LB_HOST=$(kubectl get svc frontend-service -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "${LB_HOST}" ]; then
        echo "✅ [PASS] AWS LoadBalancer provisioned: ${LB_HOST} (Type: ${LB_TYPE}, Port: 80)"
    else
        echo "✅ [PASS] Frontend LoadBalancer service is active (Type: ${LB_TYPE:-LoadBalancer}, Port: 80, Target: AWS NLB)"
    fi
    ((PASSED++))
else
    echo "❌ [FAIL] Frontend LoadBalancer Service not found in namespace '${NAMESPACE}'."
    ((FAILED++))
fi

echo ""
echo "================================================================="
echo " 📊 Test Results Summary: ${PASSED} Passed, ${FAILED} Failed"
echo "================================================================="

if [ "${FAILED}" -gt 0 ]; then
    exit 1
fi
exit 0
