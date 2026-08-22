# ==============================================================================
# Amazon ECR Repositories & Lifecycle Policies for Microservices
# ==============================================================================

locals {
  services = [
    "auth-service",
    "streaming-service",
    "admin-service",
    "chat-service",
    "frontend"
  ]
}

resource "aws_ecr_repository" "microservices" {
  for_each             = toset(local.services)
  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "${var.project_name}-${each.key}"
    Service = each.key
  }
}

# Lifecycle Policy: Keep only the latest 10 images and delete untagged images after 1 day (Cost Optimization)
resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  for_each   = aws_ecr_repository.microservices
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain maximum 10 latest tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "build-", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
