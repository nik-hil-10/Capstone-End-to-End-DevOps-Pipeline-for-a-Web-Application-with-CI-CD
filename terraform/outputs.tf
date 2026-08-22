# ==============================================================================
# Terraform Outputs
# ==============================================================================

output "aws_region" {
  description = "Deployed AWS Region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "IDs of Public Subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "IDs of Private Subnets"
  value       = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  description = "Name of the EKS Cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API Server Endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security Group ID of the EKS Cluster"
  value       = aws_security_group.eks_cluster.id
}

output "ecr_repository_urls" {
  description = "Map of ECR repository URLs for each microservice"
  value = {
    for k, v in aws_ecr_repository.microservices : k => v.repository_url
  }
}

output "configure_kubectl" {
  description = "CLI Command to update local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "jenkins_public_ip" {
  description = "Public Elastic IP of the Jenkins Controller on AWS EC2"
  value       = aws_eip.jenkins_eip.public_ip
}

output "jenkins_url" {
  description = "Web Console URL for Jenkins Server on AWS EC2"
  value       = "http://${aws_eip.jenkins_eip.public_ip}:8080"
}

