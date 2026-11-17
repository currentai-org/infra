env    = "staging"
org    = "currentai"
region = "eu-north-1"

availability_zones   = ["eu-north-1a", "eu-north-1b"]
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]
private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]
single_nat_gateway   = true

eks_name    = "cluster"
eks_version = "1.37"

rds_engine_version      = "16.11"
rds_instance_count      = 1
rds_min_capacity        = 0.5
rds_max_capacity        = 16
rds_deletion_protection = false
rds_skip_final_snapshot = true

enable_serverless_redis  = true
enable_non_cluster_redis = false
enable_holmes_mcp_iam    = true

alert_email = "sean@currentai.org"
smtp_host   = "email-smtp.eu-north-1.amazonaws.com"
