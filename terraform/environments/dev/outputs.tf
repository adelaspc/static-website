output "bucket_name" {
  description = "Name of the S3 bucket receiving frontend deployment artifacts."
  value       = module.s3.bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID used for deployment invalidations."
  value       = module.cloudfront.distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront-assigned domain name for the website distribution."
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_logs_bucket_name" {
  description = "Name of the S3 bucket that stores CloudFront Standard Logging v2 access logs."
  value       = module.s3.cloudfront_logs_bucket_name
}

output "website_urls" {
  description = "Public HTTPS URLs configured for the website."
  value       = [for name in var.domain_aliases : "https://${name}"]
}

output "github_actions_frontend_role_arn" {
  description = "ARN of the GitHub Actions role used by the frontend deployment workflow."
  value       = module.github_actions_iam.frontend_deploy_role_arn
}

output "github_actions_terraform_role_arn" {
  description = "ARN of the GitHub Actions role used by the Terraform apply workflow."
  value       = module.github_actions_iam.terraform_role_arn
}

output "github_actions_terraform_permissions_boundary_arn" {
  description = "ARN of the permissions boundary attached to the Terraform workflow role."
  value       = module.github_actions_iam.terraform_permissions_boundary_arn
}

output "cloudfront_4xx_alarm_name" {
  description = "Name of the CloudWatch alarm monitoring CloudFront 4xx errors."
  value       = module.monitoring.cloudfront_4xx_alarm_name
}

output "cloudfront_5xx_alarm_name" {
  description = "Name of the CloudWatch alarm monitoring CloudFront 5xx errors."
  value       = module.monitoring.cloudfront_5xx_alarm_name
}
