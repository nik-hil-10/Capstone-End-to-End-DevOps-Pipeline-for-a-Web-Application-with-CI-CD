# ==============================================================================
# Jenkins CI/CD Controller on AWS EC2
# ==============================================================================
# Provisions a dedicated Ubuntu 22.04 EC2 instance for Jenkins with Elastic IP,
# security groups, and an IAM Instance Profile for direct EKS/ECR management.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Latest Ubuntu 22.04 LTS AMI Data Source
# ------------------------------------------------------------------------------
data "aws_ami" "ubuntu_jenkins" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------------------------
# 2. Security Group for Jenkins Server (Web UI 8080 + SSH 22)
# ------------------------------------------------------------------------------
resource "aws_security_group" "jenkins_sg" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Security group for Jenkins CI/CD Controller on AWS EC2"
  vpc_id      = aws_vpc.main.id

  # Inbound HTTP for Jenkins Web Console
  ingress {
    description = "Allow HTTP access to Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound SSH for Configuration & Ansible Management
  ingress {
    description = "Allow SSH management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Internet Access for Package Management & AWS API calls
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-jenkins-sg"
  }
}

# ------------------------------------------------------------------------------
# 3. IAM Role & Instance Profile for Jenkins on EC2
# ------------------------------------------------------------------------------
resource "aws_iam_role" "jenkins_role" {
  name = "${var.project_name}-jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-jenkins-ec2-role"
  }
}

# Attach Administrator / PowerUser policies for ECR, EKS, and S3
resource "aws_iam_role_policy_attachment" "jenkins_admin_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.jenkins_role.name
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "${var.project_name}-jenkins-instance-profile"
  role = aws_iam_role.jenkins_role.name
}

# ------------------------------------------------------------------------------
# 4. AWS EC2 Instance for Jenkins Controller
# ------------------------------------------------------------------------------
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu_jenkins.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-jenkins-root-volume"
    }
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              # 1. Install prerequisites, Git and Ansible
              apt-get update -y
              apt-get install -y git software-properties-common curl
              add-apt-repository --yes --update ppa:ansible/ansible
              apt-get install -y ansible

              # 2. Clone Repository and execute Ansible Playbook locally
              git clone https://github.com/nik-hil-10/Capstone-End-to-End-DevOps-Pipeline-for-a-Web-Application-with-CI-CD.git /tmp/capstone
              cd /tmp/capstone/ansible
              ansible-playbook -i inventory/hosts.ini playbooks/setup_tools.yml --connection=local
              EOF

  tags = {
    Name = "${var.project_name}-jenkins-server"
    Role = "CI-CD-Controller"
  }
}

# ------------------------------------------------------------------------------
# 5. Elastic IP for Jenkins Server
# ------------------------------------------------------------------------------
resource "aws_eip" "jenkins_eip" {
  domain   = "vpc"
  instance = aws_instance.jenkins.id

  tags = {
    Name = "${var.project_name}-jenkins-eip"
  }
}
