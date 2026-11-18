locals {
  org    = "currentai"
  domain = "currentai.cloud"
  region = "eu-west-3"

  backends = {
    staging = {
      region         = "eu-north-1"
      bucket         = "staging-terraform-state-${local.org}"
      dynamodb_table = "staging-terraform-state"
    }
    prod = {
      region         = "eu-west-3"
      bucket         = "prod-terraform-state-${local.org}"
      dynamodb_table = "prod-terraform-state"
    }
  }
}
