output "distribution_id" {
  description = "ID of the CloudFront distribution serving the website."
  value       = aws_cloudfront_distribution.static_website.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution serving the website."
  value       = aws_cloudfront_distribution.static_website.arn
}

output "distribution_domain_name" {
  description = "CloudFront-assigned domain name for the distribution."
  value       = aws_cloudfront_distribution.static_website.domain_name
}
