# outputs.tf
output "cluster_endpoint" {
  description = "URL del endpoint de EKS"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_name" {
  description = "Nombre del clúster EKS"
  value       = aws_eks_cluster.eks_cluster.name
}
