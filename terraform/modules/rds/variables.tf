variable "env" {
  type        = string
  description = "Deployment environment name (e.g. staging, production)"
}

variable "org" {
  type        = string
  description = "Organization / project slug used in resource names"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the RDS cluster will be deployed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the RDS DB subnet group"
}

variable "eks_cluster_security_group_id" {
  type        = string
  description = "EKS cluster security group ID allowed to connect on port 5432"
}

variable "master_username" {
  type        = string
  description = "Master username for the Aurora PostgreSQL cluster"
  default     = "postgres"
}

variable "master_password" {
  type        = string
  description = "Master password for the Aurora PostgreSQL cluster"
  sensitive   = true
}

variable "engine_version" {
  type        = string
  description = "Aurora PostgreSQL engine version"
  default     = "16.11"
}

variable "instance_count" {
  type        = number
  description = "Number of Aurora Serverless v2 instances (1 for staging, 2+ for Multi-AZ production)"
  default     = 1
}

variable "min_capacity" {
  type        = number
  description = "Minimum Aurora Serverless v2 ACUs"
  default     = 0.5
}

variable "max_capacity" {
  type        = number
  description = "Maximum Aurora Serverless v2 ACUs"
  default     = 16
}

variable "deletion_protection" {
  type        = bool
  description = "Prevent accidental deletion of the RDS cluster"
  default     = false
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Whether to skip final snapshot when destroying the RDS cluster"
  default     = true
}

variable "backup_retention_period" {
  type        = number
  description = "Days to retain automated backups"
  default     = 7
}
