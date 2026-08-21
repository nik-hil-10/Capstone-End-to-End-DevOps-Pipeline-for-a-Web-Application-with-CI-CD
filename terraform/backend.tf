# ==============================================================================
# Terraform Remote State Configuration
# ==============================================================================
# NOTE: To use remote state, create the S3 bucket and DynamoDB table first,
# then uncomment the backend block below and run: terraform init -migrate-state
#
terraform {
  backend "s3" {
    bucket         = "capstone-devops-tf-state-791358130074"
    key            = "eks-pipeline/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "capstone-devops-tf-locks"
    encrypt        = true
  }
}
