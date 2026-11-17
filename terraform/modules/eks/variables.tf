variable "env" {
  type        = string
  description = "Deployment environment name (e.g. staging, production)"
}

variable "org" {
  type        = string
  description = "Organization / project slug used in resource names"
}

variable "eks_name" {
  type        = string
  description = "EKS cluster base name"
  default     = "main-cluster"
}

variable "eks_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster"
  default     = "1.32"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the EKS cluster control plane and nodes"
}

variable "service_ipv4_cidr" {
  type        = string
  description = "Kubernetes service IPv4 CIDR block"
  default     = "172.20.0.0/16"
}

variable "endpoint_public_access" {
  type        = bool
  description = "Whether the EKS API server public endpoint is enabled"
  default     = true
}

variable "enabled_cluster_log_types" {
  type        = list(string)
  description = "Control plane log types to enable"
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
