variable "alert_email" {
  type        = string
  description = "From/alert email address for Argo CD notifications"
  default     = "sean+infra@currentai.org"
}

variable "smtp_host" {
  type        = string
  description = "SMTP host for Argo CD email notifications"
  default     = "email-smtp.eu-west-3.amazonaws.com"
}

variable "smtp_port" {
  type        = number
  description = "SMTP port for Argo CD email notifications"
  default     = 587
}

variable "argocd_chart_version" {
  type        = string
  description = "Helm chart version for argo-cd"
  default     = "9.5.22"
}

variable "external_secrets_chart_version" {
  type        = string
  description = "Helm chart version for external-secrets"
  default     = "2.6.0"
}

variable "external_secrets_irsa_role_arn" {
  type        = string
  description = "IAM Role ARN annotated on the External Secrets Operator ServiceAccount"
}
