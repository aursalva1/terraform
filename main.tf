# main.tf
provider "aws" {
  region = var.region
}

# Crear una VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "eks-vpc"
  }
}

# Crear subnets
resource "aws_subnet" "eks_subnet" {
  count = 2
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr, 24, count.index)  # Usar /24 en lugar de /8 para subredes más razonables
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "eks-subnet-${count.index}"
  }
}

data "aws_availability_zones" "available" {}

# Crear un Internet Gateway
resource "aws_internet_gateway" "eks_internet_gateway" {
  vpc_id = aws_vpc.eks_vpc.id
}

# Crear rutas de acceso a Internet
resource "aws_route_table" "eks_route_table" {
  vpc_id = aws_vpc.eks_vpc.id
}

resource "aws_route" "eks_route" {
  route_table_id         = aws_route_table.eks_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.eks_internet_gateway.id
}

resource "aws_route_table_association" "eks_subnet_association" {
  count          = 2
  subnet_id      = aws_subnet.eks_subnet[count.index].id
  route_table_id = aws_route_table.eks_route_table.id
}

# Crear un rol de IAM para el EKS
resource "aws_iam_role" "eks_role" {
  name = "eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Crear el clúster EKS
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = aws_subnet.eks_subnet[*].id
  }

  depends_on = [aws_iam_role_policy_attachment.eks_policy_attachment]
}

# Crear el grupo de nodos
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_role.arn
  subnet_ids      = aws_subnet.eks_subnet[*].id  # Cambia 'subnets' por 'subnet_ids'

  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_size
    min_size     = var.min_size
  }

  instance_types = [var.node_instance_type]
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_version" {
  value = aws_eks_cluster.eks_cluster.version
}

output "eks_cluster_node_group" {
  value = aws_eks_node_group.eks_node_group.node_group_name
}
