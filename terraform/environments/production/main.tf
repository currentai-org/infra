resource "random_password" "rds_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "vpc" {
  source = "../../modules/vpc"

  env                  = var.env
  org                  = var.org
  eks_name             = var.eks_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

module "eks" {
  source = "../../modules/eks"

  env                = var.env
  org                = var.org
  eks_name           = var.eks_name
  eks_version        = var.eks_version
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "rds" {
  source = "../../modules/rds"

  env                           = var.env
  org                           = var.org
  vpc_id                        = module.vpc.vpc_id
  private_subnet_ids            = module.vpc.private_subnet_ids
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
  master_password               = random_password.rds_master.result
  engine_version                = var.rds_engine_version
  instance_count                = var.rds_instance_count
  min_capacity                  = var.rds_min_capacity
  max_capacity                  = var.rds_max_capacity
  deletion_protection           = var.rds_deletion_protection
  skip_final_snapshot           = var.rds_skip_final_snapshot
}

module "redis" {
  source = "../../modules/redis"

  env                           = var.env
  org                           = var.org
  vpc_id                        = module.vpc.vpc_id
  private_subnet_ids            = module.vpc.private_subnet_ids
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
  enable_serverless_cache       = var.enable_serverless_redis
  enable_replication_group      = var.enable_non_cluster_redis
}

module "secrets_iam" {
  source = "../../modules/secrets-iam"

  env                       = var.env
  org                       = var.org
  region                    = var.region
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.oidc_provider_url
  rds_endpoint              = module.rds.cluster_endpoint
  rds_master_password       = random_password.rds_master.result
  redis_endpoint            = module.redis.serverless_endpoint
  redis_port                = coalesce(module.redis.serverless_port, 6379)
  enable_holmes_mcp_iam     = var.enable_holmes_mcp_iam
  agent_service_secret_name = "prd/agent-service"
  pangolin_secret_name      = "/prd/pangolin"
  cluster_agent_secret_name = "prd/cluster-agent"
}

module "addons" {
  source = "../../modules/addons"

  alert_email                    = var.alert_email
  smtp_host                      = var.smtp_host
  external_secrets_irsa_role_arn = module.secrets_iam.external_secrets_irsa_role_arn

  depends_on = [module.eks, module.secrets_iam]
}
