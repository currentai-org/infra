data "aws_caller_identity" "current" {}

locals {
  oidc_issuer_host = replace(var.oidc_provider_url, "https://", "")
}

# --- Auto-generated passwords for monitoring ---
resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "random_password" "prometheus_admin" {
  length  = 24
  special = false
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

# --- 3. Grafana Admin Credentials (auto-generated) ---
resource "aws_secretsmanager_secret" "grafana" {
  name                    = "${var.env}/${var.org}/grafana/secrets"
  description             = "Grafana admin credentials (${var.env})"
  recovery_window_in_days = contains(["prod", "production"], var.env) ? 7 : 0

  tags = {
    Name        = "${var.env}-${var.org}-grafana-secrets"
    Environment = var.env
  }
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id = aws_secretsmanager_secret.grafana.id
  secret_string = jsonencode({
    admin-user     = "admin"
    admin-password = random_password.grafana_admin.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# --- 4. Prometheus Basic-Auth Credentials (auto-generated) ---
resource "aws_secretsmanager_secret" "prometheus" {
  name                    = "${var.env}/${var.org}/prometheus/secrets"
  description             = "Prometheus basic auth credentials (${var.env})"
  recovery_window_in_days = contains(["prod", "production"], var.env) ? 7 : 0

  tags = {
    Name        = "${var.env}-${var.org}-prometheus-secrets"
    Environment = var.env
  }
}

resource "aws_secretsmanager_secret_version" "prometheus" {
  secret_id = aws_secretsmanager_secret.prometheus.id
  secret_string = jsonencode({
    admin-user     = "admin"
    admin-password = random_password.prometheus_admin.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# --- 5. Argo CD Notifications Secret (populated manually or via Doppler) ---
resource "aws_secretsmanager_secret" "argocd_notifications" {
  name                    = "${var.env}/${var.org}/argocd/notifications"
  description             = "Secrets for ArgoCD notifications (Slack token / SMTP credentials)"
  recovery_window_in_days = contains(["prod", "production"], var.env) ? 7 : 0

  tags = {
    Name        = "${var.env}-${var.org}-argocd-notifications"
    Environment = var.env
  }
}

resource "aws_secretsmanager_secret_version" "argocd_notifications" {
  secret_id = aws_secretsmanager_secret.argocd_notifications.id
  secret_string = jsonencode({
    slack-token    = "placeholder-replace-in-console"
    email-username = "placeholder-replace-in-console"
    email-password = "placeholder-replace-in-console"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# --- 6. Data sources for existing Doppler-managed Secrets Manager secrets ---
# Data source for existing Agent Service secret
data "aws_secretsmanager_secret" "agent_service" {
  name = "/agent-service"
}

data "aws_secretsmanager_secret" "router_aipotluck_org" {
  name = "/router-aipotluck-org"
}

data "aws_secretsmanager_secret" "pangolin" {
  name = "/pangolin"
}

# --- 7. IAM Role & Policy for External Secrets Operator (IRSA) ---
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
          aws_secretsmanager_secret.grafana.arn,
          aws_secretsmanager_secret.prometheus.arn,
          aws_secretsmanager_secret.argocd_notifications.arn,
          data.aws_secretsmanager_secret.agent_service.arn,
          data.aws_secretsmanager_secret.router_aipotluck_org.arn,
          data.aws_secretsmanager_secret.pangolin.arn,
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:*cluster-agent*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets_secretsmanager" {
  role       = aws_iam_role.external_secrets_irsa.name
  policy_arn = aws_iam_policy.external_secrets_secretsmanager_access.arn
}

# --- 8. IAM Role and Policy for Holmes AWS MCP Server (IRSA) ---
resource "aws_iam_role" "holmes_mcp" {
  count = var.enable_holmes_mcp_iam ? 1 : 0

  name = "${var.env}-HolmesMCPRole"

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
            "${local.oidc_issuer_host}:sub" = "system:serviceaccount:cluster-agent:aws-api-mcp-sa"
            "${local.oidc_issuer_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.env}-${var.org}-holmes-mcp-role"
    Environment = var.env
  }
}

resource "aws_iam_policy" "holmes_mcp_readonly" {
  count = var.enable_holmes_mcp_iam ? 1 : 0

  name        = "${var.env}-HolmesMCPReadOnly"
  description = "Read-only permissions for Holmes AWS MCP server"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CoreObservability"
        Effect = "Allow"
        Action = [
          "logs:Describe*",
          "logs:Get*",
          "logs:List*",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:TestMetricFilter",
          "logs:FilterLogEvents",
          "logs:StartLiveTail",
          "logs:StopLiveTail",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "events:DescribeRule",
          "events:List*",
          "events:DescribeEventBus",
          "events:TestEventPattern"
        ]
        Resource = "*"
      },
      {
        Sid    = "ComputeAndNetworking"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:Get*",
          "ec2:SearchTransitGatewayRoutes",
          "elasticloadbalancing:Describe*",
          "autoscaling:Describe*",
          "application-autoscaling:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ContainersAndKubernetes"
        Effect = "Allow"
        Action = [
          "eks:AccessKubernetesApi",
          "eks:Describe*",
          "eks:List*",
          "ecs:Describe*",
          "ecs:List*",
          "ecr:Describe*",
          "ecr:Get*",
          "ecr:List*",
          "ecr:BatchCheck*",
          "ecr:BatchGet*"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMAndSecurity"
        Effect = "Allow"
        Action = [
          "iam:Get*",
          "iam:List*",
          "iam:Simulate*",
          "iam:GenerateCredentialReport",
          "iam:GenerateServiceLastAccessedDetails",
          "access-analyzer:Get*",
          "access-analyzer:List*",
          "cloudtrail:Get*",
          "cloudtrail:Describe*",
          "cloudtrail:List*",
          "cloudtrail:LookupEvents",
          "cloudtrail:SearchTrails",
          "guardduty:Get*",
          "guardduty:List*",
          "securityhub:Get*",
          "securityhub:List*",
          "securityhub:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DatabasesAndAnalytics"
        Effect = "Allow"
        Action = [
          "rds:Describe*",
          "rds:List*",
          "rds:Download*",
          "pi:Describe*",
          "pi:Get*",
          "pi:List*",
          "elasticache:Describe*",
          "elasticache:List*",
          "docdb:Describe*",
          "docdb:List*",
          "neptune:Describe*",
          "neptune:List*",
          "redshift:Describe*",
          "redshift:View*",
          "redshift:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "BillingAndCostManagement"
        Effect = "Allow"
        Action = [
          "ce:Get*",
          "ce:Describe*",
          "ce:List*",
          "cur:Describe*",
          "cur:List*",
          "budgets:View*",
          "budgets:Describe*",
          "pricing:Describe*",
          "pricing:Get*",
          "pricing:List*",
          "aws-portal:View*",
          "billing:Get*",
          "billing:List*",
          "account:Get*",
          "account:List*",
          "savingsplans:Describe*",
          "savingsplans:List*",
          "compute-optimizer:Get*",
          "compute-optimizer:List*",
          "organizations:Describe*",
          "organizations:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "StorageServices"
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:List*",
          "s3:Describe*",
          "s3-object-lambda:Get*",
          "s3-object-lambda:List*",
          "ebs:List*",
          "ebs:Get*",
          "efs:Describe*",
          "efs:List*",
          "fsx:Describe*",
          "fsx:List*",
          "backup:Describe*",
          "backup:Get*",
          "backup:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ServerlessAndIntegration"
        Effect = "Allow"
        Action = [
          "lambda:Get*",
          "lambda:List*",
          "states:Describe*",
          "states:Get*",
          "states:List*",
          "apigateway:GET",
          "apigatewayv2:Get*",
          "sns:Get*",
          "sns:List*",
          "sqs:Get*",
          "sqs:List*",
          "kinesis:Describe*",
          "kinesis:Get*",
          "kinesis:List*",
          "kafka:Describe*",
          "kafka:Get*",
          "kafka:List*",
          "mq:Describe*",
          "mq:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ConfigurationAndSecrets"
        Effect = "Allow"
        Action = [
          "ssm:Describe*",
          "ssm:Get*",
          "ssm:List*",
          "secretsmanager:Describe*",
          "secretsmanager:List*",
          "secretsmanager:GetResourcePolicy",
          "appconfig:Get*",
          "appconfig:List*",
          "cloudformation:Describe*",
          "cloudformation:Get*",
          "cloudformation:List*",
          "cloudformation:Detect*",
          "cloudformation:Estimate*"
        ]
        Resource = "*"
      },
      {
        Sid    = "NetworkingAndCDN"
        Effect = "Allow"
        Action = [
          "route53:Get*",
          "route53:List*",
          "route53:Test*",
          "route53resolver:Get*",
          "route53resolver:List*",
          "cloudfront:Get*",
          "cloudfront:List*",
          "globalaccelerator:Describe*",
          "globalaccelerator:List*",
          "networkmanager:Get*",
          "networkmanager:Describe*",
          "network-firewall:Describe*",
          "network-firewall:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "MonitoringAndTracing"
        Effect = "Allow"
        Action = [
          "xray:Get*",
          "xray:BatchGet*",
          "xray:List*",
          "synthetics:Describe*",
          "synthetics:Get*",
          "synthetics:List*",
          "rum:Get*",
          "rum:List*",
          "rum:BatchGet*",
          "evidently:Get*",
          "evidently:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AdditionalServices"
        Effect = "Allow"
        Action = [
          "kms:Describe*",
          "kms:Get*",
          "kms:List*",
          "acm:Describe*",
          "acm:Get*",
          "acm:List*",
          "waf:Get*",
          "waf:List*",
          "wafv2:Get*",
          "wafv2:List*",
          "wafv2:Describe*",
          "shield:Get*",
          "shield:Describe*",
          "shield:List*",
          "resource-explorer-2:Get*",
          "resource-explorer-2:List*",
          "resource-explorer-2:Search",
          "tag:Get*",
          "tag:Describe*",
          "health:Describe*",
          "health:Get*",
          "health:List*",
          "support:Describe*",
          "support:Get*",
          "support:List*",
          "trustedadvisor:Get*",
          "trustedadvisor:List*",
          "trustedadvisor:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "holmes_mcp_readonly" {
  count = var.enable_holmes_mcp_iam ? 1 : 0

  role       = aws_iam_role.holmes_mcp[0].name
  policy_arn = aws_iam_policy.holmes_mcp_readonly[0].arn
}
