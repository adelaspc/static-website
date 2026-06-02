output "bucket_id" {
  value = aws_s3_bucket.static_website.id
}

output "bucket_arn" {
  value = aws_s3_bucket.static_website.arn
}

output "bucket_name" {
  value = aws_s3_bucket.static_website.bucket
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.static_website.bucket_regional_domain_name
}

output "cloudfront_logs_bucket_domain_name" {
  value = aws_s3_bucket.cloudfront_logs.bucket_domain_name
}

output "cloudfront_logs_bucket_arn" {
  value = aws_s3_bucket.cloudfront_logs.arn
}
