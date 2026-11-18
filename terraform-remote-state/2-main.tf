module "staging_backend" {
  source = "./modules/remote-state-backend"

  providers = {
    aws = aws.staging
  }

  bucket_name         = local.backends.staging.bucket
  dynamodb_table_name = local.backends.staging.dynamodb_table
}

module "prod_backend" {
  source = "./modules/remote-state-backend"

  providers = {
    aws = aws.prod
  }

  bucket_name         = local.backends.prod.bucket
  dynamodb_table_name = local.backends.prod.dynamodb_table
}

resource "aws_route53_zone" "this" {
  name = local.domain
}
