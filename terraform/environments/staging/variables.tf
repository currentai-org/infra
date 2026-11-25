variable "env" {
  type        = string
  description = "Environment name"
}

variable "org" {
  type        = string
  description = "Organization / project slug"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "availability_zones" {
  type        = list(string)
  description = "Two availability zones in the target region"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDR blocks"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDR blocks"
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use a single NAT gateway for cost savings"
}

variable "eks_name" {
  type        = string
  description = "EKS cluster base name"
}

variable "eks_version" {
  type        = string
  description = "Kubernetes version"
}

variable "rds_engine_version" {
  type        = string
  description = "Aurora PostgreSQL engine version"
}

variable "rds_instance_count" {
  type        = number
  description = "Number of Aurora Serverless v2 instances"
}

variable "rds_min_capacity" {
  type        = number
  description = "Minimum Aurora ACUs"
}

variable "rds_max_capacity" {
  type        = number
  description = "Maximum Aurora ACUs"
}

variable "rds_deletion_protection" {
  type        = bool
  description = "Enable RDS deletion protection"
}

variable "rds_skip_final_snapshot" {
  type        = bool
  description = "Skip final RDS snapshot on destroy"
}

variable "enable_serverless_redis" {
  type        = bool
  description = "Enable ElastiCache Serverless Valkey"
}

variable "enable_non_cluster_redis" {
  type        = bool
  description = "Enable non-cluster ElastiCache Redis replication group"
}

variable "alert_email" {
  type        = string
  description = "Alert email for Argo CD notifications"
}

variable "smtp_host" {
  type        = string
  description = "SMTP server hostname for Argo CD notifications"
}
