output "staging_s3_bucket_arn" {
  description = "The ARN of the staging S3 state bucket."
  value       = module.staging_backend.s3_bucket_arn
}

output "staging_dynamodb_table_name" {
  description = "The name of the staging DynamoDB lock table."
  value       = module.staging_backend.dynamodb_table_name
}

output "prod_s3_bucket_arn" {
  description = "The ARN of the production S3 state bucket."
  value       = module.prod_backend.s3_bucket_arn
}

output "prod_dynamodb_table_name" {
  description = "The name of the production DynamoDB lock table."
  value       = module.prod_backend.dynamodb_table_name
}

output "name_servers" {
  description = "Set these 4 name servers at your domain registrar."
  value       = aws_route53_zone.this.name_servers
}
