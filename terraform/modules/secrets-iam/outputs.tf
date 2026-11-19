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

output "infra_secret_name" {
  description = "Name of the shared Doppler-synced infra secret"
  value       = data.aws_secretsmanager_secret.infra.name
}
