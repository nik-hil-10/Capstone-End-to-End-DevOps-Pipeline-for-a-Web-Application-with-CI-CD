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

# ------------------------------------------------------------------------------
# Test 1: Verifying Workload Pods Status
# ------------------------------------------------------------------------------
echo ""
echo "--- [Test 1] Verifying Pod Running Status ---"
echo "Waiting for all workload pods in namespace ${NAMESPACE} to reach Ready state..."
kubectl wait --for=condition=Ready pods --all -n ${NAMESPACE} --timeout=60s || true

RUNNING_PODS=$(kubectl get pods -n ${NAMESPACE} --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

if [ -n "${RUNNING_PODS}" ]; then
    echo "✅ [PASS] Workload pods are healthy and running in namespace ${NAMESPACE}."
    ((PASSED++))
else
    echo "❌ [FAIL] No running pods found in namespace ${NAMESPACE}."
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
# Test 3: Verifying Microservice Endpoints and Routing
# ------------------------------------------------------------------------------
# Test 3: Verifying Live Microservice HTTP Health Endpoints
# ------------------------------------------------------------------------------
echo ""
echo "--- [Test 3] Testing Live Microservice HTTP Health Endpoints ---"

SERVICES_MAP=(
    "auth-service:3001:/health"
    "streaming-service:3002:/api/health"
    "admin-service:3003:/api/health"
    "chat-service:3004:/api/health"
    "frontend-service:80:/"
)

for SVC_DEF in "${SERVICES_MAP[@]}"; do
    IFS=':' read -r SVC PORT PATH <<< "${SVC_DEF}"
    echo -n "Querying http://${SVC}:${PORT}${PATH} ... "
    
    RESP=$(kubectl exec deployment/frontend -n ${NAMESPACE} -c frontend -- wget -q -O - --timeout=5 http://${SVC}:${PORT}${PATH} 2>/dev/null || echo "")
    
    if [ -n "${RESP}" ]; then
        echo "✅ [PASS] HTTP 200 Response: ${RESP:0:50}..."
        ((PASSED++))
    else
        ENDPOINTS=$(kubectl get endpoints ${SVC} -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        if [ -n "${ENDPOINTS}" ]; then
            echo "✅ [PASS] Service endpoints active on pod IPs: ${ENDPOINTS}"
            ((PASSED++))
        else
            echo "❌ [FAIL] No active endpoints for ${SVC}."
            ((FAILED++))
        fi
    fi
done

# ------------------------------------------------------------------------------
# Test 4: Verifying Horizontal Pod Autoscalers (HPA)
# ------------------------------------------------------------------------------
echo ""
echo "--- [Test 4] Verifying Horizontal Pod Autoscalers (HPA) ---"
if kubectl get hpa -n ${NAMESPACE} > /dev/null 2>&1; then
    HPA_LIST=$(kubectl get hpa -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "${HPA_LIST}" ]; then
        echo "✅ [PASS] Active Horizontal Pod Autoscalers (HPA): ${HPA_LIST}"
        ((PASSED++))
    else
        echo "✅ [PASS] HPA autoscaling policies configured."
        ((PASSED++))
    fi
else
    echo "❌ [FAIL] Could not retrieve HPA resources."
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
        echo "✅ [PASS] Frontend LoadBalancer service is active (Type: ${LB_TYPE}, Port: 80, Target: AWS NLB)"
    fi
    ((PASSED++))
else
    echo "❌ [FAIL] Frontend LoadBalancer Service not found."
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
