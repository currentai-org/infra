locals {
  org     = "currentai"
  domain  = "currentai.cloud"
  env     = "prod"   # must be set to "prod" to enable prod resources like rds deletion protection
  region  = "eu-west-3" #
  s3state = "${local.env}-terraform-state-${local.org}"
}
