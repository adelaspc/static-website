output "bucket_id" {
  description = "ID of the private S3 bucket that stores website assets."
  value       = aws_s3_bucket.static_website.id
}

output "bucket_arn" {
  description = "ARN of the private S3 bucket that stores website assets."
  value       = aws_s3_bucket.static_website.arn
}

output "bucket_name" {
  description = "Name of the private S3 bucket that stores website assets."
  value       = aws_s3_bucket.static_website.bucket
}

output "bucket_regional_domain_name" {
  description = "Regional S3 domain name used as the CloudFront origin."
  value       = aws_s3_bucket.static_website.bucket_regional_domain_name
}

output "cloudfront_logs_bucket_arn" {
  description = "ARN of the ACL-disabled S3 bucket authorized for CloudFront Standard Logging v2 delivery."
  value       = aws_s3_bucket.cloudfront_logs.arn

  depends_on = [
    aws_s3_bucket_ownership_controls.cloudfront_logs,
    aws_s3_bucket_policy.cloudfront_logs,
  ]
}

output "cloudfront_logs_bucket_name" {
  description = "Name of the S3 bucket that stores CloudFront Standard Logging v2 access logs."
  value       = aws_s3_bucket.cloudfront_logs.bucket
}
