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
  description = "VPC ID where ElastiCache will be deployed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ElastiCache"
}

variable "eks_cluster_security_group_id" {
  type        = string
  description = "EKS cluster security group ID allowed to connect on port 6379"
}

variable "enable_serverless_cache" {
  type        = bool
  description = "Whether to provision an ElastiCache Serverless Valkey cache"
  default     = true
}

variable "valkey_major_engine_version" {
  type        = string
  description = "Major engine version for ElastiCache Serverless Valkey"
  default     = "8"
}

variable "enable_replication_group" {
  type        = bool
  description = "Whether to provision a non-cluster ElastiCache Redis replication group"
  default     = false
}

variable "replication_group_node_type" {
  type        = string
  description = "Node type for non-cluster ElastiCache Redis replication group"
  default     = "cache.t4g.micro"
}

variable "replication_group_num_cache_clusters" {
  type        = number
  description = "Number of cache nodes in the non-cluster ElastiCache replication group"
  default     = 1
}
