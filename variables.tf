# variables.tf
variable "region" {
  description = "Región de AWS donde se creará el clúster"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nombre del clúster EKS"
  default     = "my-eks-cluster"
}

variable "node_instance_type" {
  description = "Tipo de instancia de EC2 para los nodos de trabajo"
  default     = "t3.medium"
}

variable "desired_capacity" {
  description = "Número deseado de nodos de trabajo"
  default     = 2
}

variable "max_size" {
  description = "Tamaño máximo del grupo de nodos"
  default     = 3
}

variable "min_size" {
  description = "Tamaño mínimo del grupo de nodos"
  default     = 1
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  default     = "10.0.0.0/16"
}
