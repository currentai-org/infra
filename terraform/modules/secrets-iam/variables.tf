variable "env" {
  type        = string
  description = "Deployment environment name (e.g. staging, production)"
}

variable "org" {
  type        = string
  description = "Organization / project slug used in resource names"
}

variable "region" {
  type        = string
  description = "AWS region for the environment"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS OIDC provider"
}

variable "oidc_provider_url" {
  type        = string
  description = "URL of the EKS OIDC provider"
}

variable "rds_endpoint" {
  type        = string
  description = "Aurora PostgreSQL cluster writer endpoint"
}

variable "rds_master_username" {
  type        = string
  description = "Aurora PostgreSQL master username"
  default     = "postgres"
}

variable "rds_master_password" {
  type        = string
  description = "Aurora PostgreSQL master password"
  sensitive   = true
}

variable "redis_endpoint" {
  type        = string
  description = "ElastiCache Valkey/Redis endpoint address (nullable if disabled)"
  default     = null
}

variable "redis_port" {
  type        = number
  description = "ElastiCache Valkey/Redis port"
  default     = 6379
}

variable "enable_holmes_mcp_iam" {
  type        = bool
  description = "Whether to create the IRSA role for HolmesGPT AWS MCP server"
  default     = true
}
