output "cluster_endpoint" {
  description = "Writer endpoint for the Aurora PostgreSQL cluster"
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint for the Aurora PostgreSQL cluster"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_port" {
  description = "Port for the Aurora PostgreSQL cluster"
  value       = aws_rds_cluster.this.port
}

output "security_group_id" {
  description = "Security group ID for the RDS cluster"
  value       = aws_security_group.db.id
}
