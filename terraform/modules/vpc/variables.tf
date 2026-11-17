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
  description = "EKS cluster base name (used for Kubernetes subnet discovery tags)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of two availability zones for public and private subnets"

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly two availability zones must be provided."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the two public subnets"
  default     = ["10.0.0.0/20", "10.0.16.0/20"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs must be provided."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the two private subnets"
  default     = ["10.0.128.0/20", "10.0.144.0/20"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnet CIDRs must be provided."
  }
}

variable "single_nat_gateway" {
  type        = bool
  description = "If true, provision a single NAT Gateway for all private subnets (cost saving for staging). If false, provision one NAT Gateway per AZ."
  default     = true
}
