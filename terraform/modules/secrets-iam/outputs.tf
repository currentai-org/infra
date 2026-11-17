output "external_secrets_irsa_role_arn" {
  description = "IAM Role ARN for External Secrets Operator IRSA"
  value       = aws_iam_role.external_secrets_irsa.arn
}

output "holmes_mcp_role_arn" {
  description = "IAM Role ARN for Holmes AWS MCP server IRSA"
  value       = var.enable_holmes_mcp_iam ? aws_iam_role.holmes_mcp[0].arn : null
}

output "rds_password_secret_arn" {
  description = "ARN of the RDS master password secret"
  value       = aws_secretsmanager_secret.rds_password.arn
}

output "infra_managed_secret_arn" {
  description = "ARN of the Terraform-managed DB/Redis metadata secret"
  value       = aws_secretsmanager_secret.infra_managed.arn
}

output "grafana_secret_name" {
  description = "Name of the Grafana admin credentials secret"
  value       = aws_secretsmanager_secret.grafana.name
}

output "prometheus_secret_name" {
  description = "Name of the Prometheus basic auth credentials secret"
  value       = aws_secretsmanager_secret.prometheus.name
}

output "argocd_notifications_secret_name" {
  description = "Name of the Argo CD notifications secret"
  value       = aws_secretsmanager_secret.argocd_notifications.name
}
