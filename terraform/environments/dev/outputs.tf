output "bucket_name" {
  value = module.s3.bucket_name
}

output "cloudfront_distribution_id" {
  value = module.cloudfront.distribution_id
}

output "cloudfront_domain_name" {
  value = module.cloudfront.distribution_domain_name
}

output "website_urls" {
  value = [for name in var.domain_aliases : "https://${name}"]
}

output "github_actions_frontend_role_arn" {
  value = module.github_actions_iam.frontend_deploy_role_arn
}

output "github_actions_terraform_role_arn" {
  value = module.github_actions_iam.terraform_role_arn
}

output "github_actions_terraform_plan_role_arn" {
  value = module.github_actions_iam.terraform_plan_role_arn
}

output "cloudfront_4xx_alarm_name" {
  value = module.monitoring.cloudfront_4xx_alarm_name
}

output "cloudfront_5xx_alarm_name" {
  value = module.monitoring.cloudfront_5xx_alarm_name
}
