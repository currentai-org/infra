variable "bucket_name" {
  description = "Name of the S3 bucket used to store Terraform state."
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  type        = string
}
