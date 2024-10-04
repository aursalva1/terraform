provider "aws" {
  region = var.aws_region
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.30"
  subnets         = ["subnet-0bb1c79de3EXAMPLE", "subnet-0bb1c79de4EXAMPLE"]  # Reemplaza con tus subnets
  vpc_id          = "vpc-xxxxxx"  # Reemplaza con tu VPC

  node_groups = {
    eks_nodes = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1

      instance_type = "t3.medium"
    }
  }
}

output "cluster_name" {
  value = module.eks.cluster_id
}

output "kubeconfig" {
  value = module.eks.kubeconfig
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
