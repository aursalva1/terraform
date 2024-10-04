variable "aws_region" {
  description = "La región donde se desplegará el clúster"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "El nombre del clúster EKS"
  default     = "my-eks-cluster"
}
