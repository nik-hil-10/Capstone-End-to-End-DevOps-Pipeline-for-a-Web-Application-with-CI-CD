# 08. Troubleshooting & Operations Runbook

## 1. Quick Diagnostic Commands

```bash
# 1. Check all pods across the cluster
kubectl get pods -n streamingapp -o wide

# 2. Inspect events on a failing pod
kubectl describe pod <pod-name> -n streamingapp

# 3. View live container logs
kubectl logs -f <pod-name> -n streamingapp

# 4. Check status of AWS EKS cluster
aws eks describe-cluster --name streaming-eks-cluster --region ap-south-1 --query "cluster.status"

# 5. Check nodes health and resource capacity
kubectl top nodes
kubectl top pods -n streamingapp
```

---

## 2. Common Scenarios & Resolutions

### Issue 1: `ImagePullBackOff` or `ErrImagePull`
*   **Root Cause:** Kubernetes cannot pull the container image from Amazon ECR due to authentication expiration, incorrect repository URI, or missing IAM permissions on the node group.
*   **Resolution:**
    1. Verify image exists in ECR: `aws ecr list-images --repository-name streaming-platform/auth-service --region ap-south-1`
    2. Confirm worker node IAM role has `AmazonEC2ContainerRegistryReadOnly` policy attached.
    3. Verify ECR login: `aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com`

---

### Issue 2: `CrashLoopBackOff` on Microservice Pods
*   **Root Cause:** Container crashes immediately after starting, typically due to missing environment variables (e.g. `MONGO_URI`, `JWT_SECRET`) or MongoDB connectivity failure.
*   **Resolution:**
    1. Check container error output: `kubectl logs <pod-name> -n streamingapp --previous`
    2. Confirm MongoDB pod is in `Running` state: `kubectl get pods -n streamingapp -l app=mongo`
    3. Verify ConfigMap and Secret are applied: `kubectl get configmap,secret -n streamingapp`

---

### Issue 3: Terraform State Locking Error (`Error acquiring the state lock`)
*   **Root Cause:** A previous Terraform run was interrupted or crashed, leaving the lock in DynamoDB.
*   **Resolution:**
    1. Retrieve the `Lock ID` from the error message.
    2. Force unlock the state: `terraform force-unlock <LOCK-ID>`

---

### Issue 4: `Pending` Pods with `0/2 nodes are available: insufficient cpu`
*   **Root Cause:** Requested CPU/memory allocations exceed available worker node capacity.
*   **Resolution:**
    1. Inspect node capacity: `kubectl describe nodes | grep -A 5 "Allocated resources"`
    2. Scale the worker node group in `terraform/variables.tf` (increase `desired_nodes = 3`) and run `terraform apply`.

---

### Issue 5: Kubernetes LoadBalancer Stuck in `<pending>` External IP
*   **Root Cause:** Missing subnet tags required by AWS Cloud Controller Manager or insufficient IAM permissions.
*   **Resolution:**
    1. Ensure public subnets have the tag: `kubernetes.io/role/elb = 1`
    2. Ensure private subnets have the tag: `kubernetes.io/role/internal-elb = 1`
    3. Verify with: `aws ec2 describe-subnets --filters "Name=vpc-id,Values=<VPC_ID>" --query "Subnets[*].Tags"`
