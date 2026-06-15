module "s3" {
  source = "../modules/s3"

  project     = var.project
  environment = var.environment
  bucket_name = var.bucket_name
}

module "acm_certificate" {
  source = "../modules/acm-cloudflare"

  providers = {
    aws = aws.us_east_1
  }

  zone_name    = var.cloudflare_zone_name
  domain_names = var.domain_aliases
}

module "cloudfront" {
  source = "../modules/cloudfront"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project                     = var.project
  environment                 = var.environment
  bucket_regional_domain_name = module.s3.bucket_regional_domain_name
  aliases                     = var.domain_aliases
  acm_certificate_arn         = module.acm_certificate.certificate_arn
  logging_bucket_arn          = module.s3.cloudfront_logs_bucket_arn
}

module "cloudflare_dns" {
  source = "../modules/cloudflare-dns"

  zone_name                    = var.cloudflare_zone_name
  record_names                 = var.domain_aliases
  cloudfront_distribution_name = module.cloudfront.distribution_domain_name
}

module "github_actions_iam" {
  source = "../modules/github-actions-iam"

  project                     = var.project
  environment                 = var.environment
  github_repository           = var.github_repository
  website_bucket_arn          = module.s3.bucket_arn
  cloudfront_logs_bucket_arn  = module.s3.cloudfront_logs_bucket_arn
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
  terraform_state_bucket_name = var.terraform_state_bucket_name
}

module "monitoring" {
  source = "../modules/monitoring"

  providers = {
    aws = aws.us_east_1
  }

  project                             = var.project
  environment                         = var.environment
  cloudfront_distribution_id          = module.cloudfront.distribution_id
  cloudfront_4xx_error_rate_threshold = var.cloudfront_4xx_error_rate_threshold
  cloudfront_5xx_error_rate_threshold = var.cloudfront_5xx_error_rate_threshold
  alarm_actions                       = var.cloudwatch_alarm_actions
  ok_actions                          = var.cloudwatch_ok_actions
}
