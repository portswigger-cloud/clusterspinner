# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "region" {
  description = "AWS region used for the cluster."
  value       = var.region
}

output "configure_kubectl" {
  description = "Command to update kubeconfig for the new cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
}
