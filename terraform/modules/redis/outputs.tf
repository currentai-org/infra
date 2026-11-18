output "serverless_endpoint" {
  description = "Endpoint address for ElastiCache Serverless Valkey cache"
  value       = var.enable_serverless_cache ? aws_elasticache_serverless_cache.this[0].endpoint[0].address : null
}

output "serverless_port" {
  description = "Port for ElastiCache Serverless Valkey cache"
  value       = var.enable_serverless_cache ? aws_elasticache_serverless_cache.this[0].endpoint[0].port : null
}

output "replication_group_endpoint" {
  description = "Primary endpoint address for non-cluster ElastiCache Redis replication group"
  value       = var.enable_replication_group ? aws_elasticache_replication_group.non_cluster[0].primary_endpoint_address : null
}

output "replication_group_port" {
  description = "Port for non-cluster ElastiCache Redis replication group"
  value       = var.enable_replication_group ? aws_elasticache_replication_group.non_cluster[0].port : null
}

output "security_group_id" {
  description = "Security group ID for ElastiCache"
  value       = aws_security_group.elasticache.id
}
