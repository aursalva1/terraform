# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.region
}

# IAM role for EKS cluster
resource "aws_iam_role" "eks_role" {
  name               = "eks_role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
}

# IAM role for EKS worker nodes
resource "aws_iam_role" "eks_node_role" {
  name               = "eks_node_role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role_policy.json
}

# Attach policies to EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_role_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

resource "aws_iam_role_policy_attachment" "eks_role_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_role.name
}

# Attach policies to EKS worker node role
resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eks_node_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Fetch availability zones
data "aws_availability_zones" "available" {}

# Create VPC for EKS cluster
resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr
}

# Create public subnets
resource "aws_subnet" "eks_public_subnet_1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "eks_public_subnet_2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
}

# Create private subnets
resource "aws_subnet" "eks_private_subnet_1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_subnet" "eks_private_subnet_2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
}

# Create internet gateway
resource "aws_internet_gateway" "eks_internet_gateway" {
  vpc_id = aws_vpc.eks_vpc.id
}

# Create route table for public subnets
resource "aws_route_table" "eks_public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_internet_gateway.id
  }
}

# Associate route table with public subnets
resource "aws_route_table_association" "eks_public_subnet_association_1" {
  subnet_id      = aws_subnet.eks_public_subnet_1.id
  route_table_id = aws_route_table.eks_public_route_table.id
}

resource "aws_route_table_association" "eks_public_subnet_association_2" {
  subnet_id      = aws_subnet.eks_public_subnet_2.id
  route_table_id = aws_route_table.eks_public_route_table.id
}

# Create security group for EKS nodes
resource "aws_security_group" "eks_node_sg" {
  vpc_id = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Fetch latest Amazon EKS AMI
data "aws_ami" "eks" {
  most_recent = true
  owners      = ["602401143452"]  # Amazon EKS AMIs

  filter {
    name   = "name"
    values = ["amazon-eks-node-*"]
  }
}

# Create launch template for worker nodes
resource "aws_launch_template" "eks_launch_template" {
  name_prefix   = "eks-launch-template-"
  image_id      = data.aws_ami.eks.id
  instance_type = var.node_instance_type  # Use the variable defined

  iam_instance_profile {
    name = aws_iam_role.eks_node_role.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.eks_node_sg.id]
  }
}

# Create the EKS cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.eks_public_subnet_1.id,
      aws_subnet.eks_public_subnet_2.id
    ]
  }
}

# Create EKS node group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.eks_public_subnet_1.id, aws_subnet.eks_public_subnet_2.id]

  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_size
    min_size     = var.min_size
  }

  depends_on = [aws_eks_cluster.eks_cluster]
}

# Outputs
output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "node_group_name" {
  value = aws_eks_node_group.eks_node_group.node_group_name
}
