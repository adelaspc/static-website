variable "project" {
  type        = string
  description = "Project name used for naming IAM resources."
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
}

variable "github_repository" {
  type        = string
  description = "GitHub repository allowed to assume the roles, in owner/repo format."
}

variable "website_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket that stores the deployed frontend files."
}

variable "cloudfront_logs_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket that stores CloudFront standard logs."
}

variable "cloudfront_distribution_arn" {
  type        = string
  description = "CloudFront distribution ARN used by the frontend deployment workflow."
}

variable "terraform_state_bucket_name" {
  type        = string
  description = "S3 bucket name used by the Terraform remote backend."
}

variable "terraform_state_key" {
  type        = string
  description = "S3 object key used by the Terraform remote backend for this environment."
}
