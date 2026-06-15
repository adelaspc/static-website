output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform remote state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket that stores Terraform remote state."
  value       = aws_s3_bucket.terraform_state.arn
}
