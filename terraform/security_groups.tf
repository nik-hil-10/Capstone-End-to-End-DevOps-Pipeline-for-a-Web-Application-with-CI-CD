# ==============================================================================
# Security Groups Configuration for EKS Cluster & Nodes
# ==============================================================================

# EKS Cluster Control Plane Security Group
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane communication"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-cluster-sg"
  }
}

# EKS Worker Nodes Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg"
  description = "Security group for all nodes in the EKS cluster"
  vpc_id      = aws_vpc.main.id

  # Allow all node-to-node communication
  ingress {
    description = "Allow nodes to communicate with each other"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Allow control plane to communicate with worker nodes
  ingress {
    description     = "Allow control plane to communicate with worker nodes"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # Allow control plane to reach pods on port 443
  ingress {
    description     = "Allow control plane to communicate with pods"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                           = "${var.project_name}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
  }
}

# Allow worker nodes to reach the EKS Cluster control plane API server
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

# Allow Jenkins Controller to reach the EKS Cluster control plane API server
resource "aws_security_group_rule" "cluster_ingress_jenkins_https" {
  description              = "Allow Jenkins CI/CD controller to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.jenkins_sg.id
}

