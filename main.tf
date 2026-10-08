terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.6.0"
}

provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "trend_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "trend-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "trend_public_subnet" {
  vpc_id                  = aws_vpc.trend_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1d"
  map_public_ip_on_launch = true

  tags = {
    Name = "trend-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "trend_igw" {
  vpc_id = aws_vpc.trend_vpc.id

  tags = {
    Name = "trend-igw"
  }
}

# Route Table
resource "aws_route_table" "trend_public_rt" {
  vpc_id = aws_vpc.trend_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.trend_igw.id
  }

  tags = {
    Name = "trend-public-rt"
  }
}

# Associate Route Table with Public Subnet
resource "aws_route_table_association" "trend_public_association" {
  subnet_id      = aws_subnet.trend_public_subnet.id
  route_table_id = aws_route_table.trend_public_rt.id
}
# Security Group for Jenkins EC2
resource "aws_security_group" "jenkins_sg" {
  name        = "trend-jenkins-sg"
  description = "Security group for Jenkins server"
  vpc_id      = aws_vpc.trend_vpc.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins
  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Trend application
  ingress {
    description = "Trend application"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "trend-jenkins-sg"
  }
}
# IAM Role for Jenkins EC2
resource "aws_iam_role" "jenkins_role" {
  name = "trend-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "trend-jenkins-role"
  }
}

# IAM Policy for Jenkins
resource "aws_iam_role_policy" "jenkins_policy" {
  name = "trend-jenkins-policy"
  role = aws_iam_role.jenkins_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:*",
          "eks:*",
          "ecr:*",
          "iam:PassRole"
        ]

        Resource = "*"
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "trend-jenkins-profile"
  role = aws_iam_role.jenkins_role.name
}
# Jenkins EC2 Instance
resource "aws_instance" "jenkins_server" {
  ami                         = "ami-0d27e0fb3bac4d724"
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.trend_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  key_name                    = "second key pair"
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.jenkins_profile.name

  user_data = <<-EOF
              #!/bin/bash

              # Update packages
              dnf update -y

              # Install Java, Git and other required packages
              dnf install -y java-17-amazon-corretto git wget curl

              # Install Docker
              dnf install -y docker
              systemctl enable docker
              systemctl start docker

              # Allow ec2-user to use Docker
              usermod -aG docker ec2-user

              # Install Jenkins repository
              wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo

              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

              # Install Jenkins
              dnf install -y jenkins

              # Start Jenkins
              systemctl enable jenkins
              systemctl start jenkins

              # Allow Jenkins to use Docker
              usermod -aG docker jenkins

              # Restart Jenkins after Docker group change
              systemctl restart jenkins
              EOF

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "trend-jenkins-server"
  }
}
