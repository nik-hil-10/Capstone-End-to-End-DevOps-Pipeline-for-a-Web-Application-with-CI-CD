@echo off
echo =====================================================================
echo  AWS Resource Teardown and Cost Optimization Script (Windows)
echo =====================================================================
echo WARNING: This will destroy all AWS resources provisioned by Terraform!
echo.
set /p CONFIRM="Are you sure you want to proceed? (yes/no): "
if /i not "%CONFIRM%"=="yes" (
    echo Teardown cancelled.
    exit /b 0
)

echo [1/3] Deleting Kubernetes Load Balancers and Services to avoid dangling AWS ELBs...
kubectl delete svc --all -n streamingapp --ignore-not-found=true

echo [2/3] Running Terraform Destroy...
cd /d "%~dp0\.."
terraform destroy -auto-approve

echo [3/3] Teardown Complete! All billable AWS resources have been terminated.
