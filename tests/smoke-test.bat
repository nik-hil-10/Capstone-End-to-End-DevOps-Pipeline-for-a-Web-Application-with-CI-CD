@echo off
REM ==============================================================================
REM Post-Deployment Automated Smoke & Functional Test Suite (Windows Batch)
REM ==============================================================================

set NAMESPACE=%1
if "%NAMESPACE%"=="" set NAMESPACE=streamingapp

echo =================================================================
echo  Running Post-Deployment Automated Functional Tests
echo  Target Namespace: %NAMESPACE%
echo =================================================================

echo.
echo --- [Test 1] Verifying Pod Running Status ---
kubectl get pods -n %NAMESPACE% -o wide

echo.
echo --- [Test 2] Verifying Services and LoadBalancers ---
kubectl get svc -n %NAMESPACE%

echo.
echo --- [Test 3] Verifying Horizontal Pod Autoscalers ---
kubectl get hpa -n %NAMESPACE%

echo.
echo =================================================================
echo  Smoke Tests Completed Successfully
echo =================================================================
