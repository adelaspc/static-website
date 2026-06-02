output "distribution_id" {
  value = aws_cloudfront_distribution.static_website.id
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.static_website.arn
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.static_website.domain_name
}
