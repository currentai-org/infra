output "s3_bucket_id" {
  description = "The name/ID of the S3 state bucket."
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB lock table."
  value       = aws_dynamodb_table.terraform_state.name
}

output "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB lock table."
  value       = aws_dynamodb_table.terraform_state.arn
}
