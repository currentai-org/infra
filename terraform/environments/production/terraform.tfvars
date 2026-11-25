env    = "prod"
org    = "currentai"
region = "eu-west-3"

availability_zones   = ["eu-west-3a", "eu-west-3b"]
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.0.0/20", "10.1.16.0/20"]
private_subnet_cidrs = ["10.1.128.0/20", "10.1.144.0/20"]
single_nat_gateway   = false

eks_name    = "cluster"
eks_version = "1.37"

rds_engine_version      = "16.11"
rds_instance_count      = 2
rds_min_capacity        = 0.5
rds_max_capacity        = 64
rds_deletion_protection = true
rds_skip_final_snapshot = false

enable_serverless_redis  = true
enable_non_cluster_redis = false

alert_email = "sean@currentai.org"
smtp_host   = "email-smtp.eu-west-3.amazonaws.com"
