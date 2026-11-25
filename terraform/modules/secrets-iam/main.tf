data "aws_caller_identity" "current" {}

locals {
  oidc_issuer_host = replace(var.oidc_provider_url, "https://", "")
}

# --- 1. RDS Master Password Secret ---
resource "aws_secretsmanager_secret" "rds_password" {
  name                    = "${var.env}/${var.org}/database/password"
  description             = "Terraform-generated database master password (${var.env})"
  recovery_window_in_days = contains(["prod", "production"], var.env) ? 7 : 0

  tags = {
    Name        = "${var.env}-${var.org}-database-password"
    Environment = var.env
  }
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    password = var.rds_master_password
  })
}

# --- 2. Auto-generated Database & Redis Endpoint Metadata ---
resource "aws_secretsmanager_secret" "infra_managed" {
  name                    = "${var.env}/${var.org}/database/managed-secrets"
  description             = "Terraform-managed DB and Redis connection metadata (${var.env})"
  recovery_window_in_days = contains(["prod", "production"], var.env) ? 7 : 0

  tags = {
    Name        = "${var.env}-${var.org}-database-managed-secrets"
    Environment = var.env
  }
}

resource "aws_secretsmanager_secret_version" "infra_managed" {
  secret_id = aws_secretsmanager_secret.infra_managed.id
  secret_string = jsonencode(merge(
    {
      DB_HOST         = var.rds_endpoint
      DB_PORT         = "5432"
      DB_USER         = var.rds_master_username
      DB_PASSWORD_ARN = aws_secretsmanager_secret.rds_password.arn
    },
    var.redis_endpoint != null ? {
      REDIS_URL  = "rediss://${var.redis_endpoint}:${var.redis_port}"
      REDIS_HOST = var.redis_endpoint
    } : {}
  ))
}

# --- 3. Data sources for existing Doppler-managed Secrets Manager secrets ---
data "aws_secretsmanager_secret" "agent_service" {
  name = var.agent_service_secret_name
}

data "aws_secretsmanager_secret" "pangolin" {
  name = var.pangolin_secret_name
}

data "aws_secretsmanager_secret" "infra" {
  name = var.infra_secret_name
}

# --- 4. IAM Role & Policy for External Secrets Operator (IRSA) ---
resource "aws_iam_role" "external_secrets_irsa" {
  name = "${var.env}-ExternalSecrets-IRSA-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_host}:sub" = "system:serviceaccount:external-secrets:external-secrets"
            "${local.oidc_issuer_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.env}-${var.org}-external-secrets-irsa-role"
    Environment = var.env
  }
}

resource "aws_iam_policy" "external_secrets_secretsmanager_access" {
  name        = "${var.env}-ExternalSecrets-SecretsManager-Policy"
  description = "Allows External Secrets Operator to retrieve application and monitoring secrets from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.rds_password.arn,
          aws_secretsmanager_secret.infra_managed.arn,
          data.aws_secretsmanager_secret.agent_service.arn,
          data.aws_secretsmanager_secret.pangolin.arn,
          data.aws_secretsmanager_secret.infra.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets_secretsmanager" {
  role       = aws_iam_role.external_secrets_irsa.name
  policy_arn = aws_iam_policy.external_secrets_secretsmanager_access.arn
}
