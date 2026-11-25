output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "rds_cluster_endpoint" {
  description = "Aurora PostgreSQL writer endpoint"
  value       = module.rds.cluster_endpoint
}

output "redis_serverless_endpoint" {
  description = "ElastiCache Serverless Valkey endpoint"
  value       = module.redis.serverless_endpoint
}

output "external_secrets_irsa_role_arn" {
  description = "IAM Role ARN for External Secrets Operator IRSA"
  value       = module.secrets_iam.external_secrets_irsa_role_arn
}
