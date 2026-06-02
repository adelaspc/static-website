variable "region" {
  type        = string
  description = "AWS region for regional resources."

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "The region must be a valid AWS region identifier, for example eu-central-1."
  }
}

variable "project" {
  type        = string
  description = "Project name used for naming and tagging resources."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.project))
    error_message = "The project value must use lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment name."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment must be one of: dev, staging, prod."
  }
}

variable "bucket_name" {
  type        = string
  description = "Environment-specific suffix used in the S3 bucket name."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "The bucket_name value must be compatible with S3 bucket naming rules."
  }
}

variable "domain_aliases" {
  type        = list(string)
  description = "Domain names served by the CloudFront distribution and Cloudflare DNS records."

  validation {
    condition = length(var.domain_aliases) > 0 && alltrue([
      for alias in var.domain_aliases : can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", alias))
    ])
    error_message = "domain_aliases must contain at least one valid lowercase DNS name."
  }
}

variable "cloudflare_zone_name" {
  type        = string
  description = "Cloudflare zone name that contains the DNS records."

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.cloudflare_zone_name))
    error_message = "The Cloudflare zone name must be a valid DNS zone name."
  }
}

variable "github_repository" {
  type        = string
  description = "GitHub repository allowed to assume the GitHub Actions IAM roles, in owner/repo format."

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must use the owner/repo format."
  }
}

variable "terraform_state_bucket_name" {
  type        = string
  description = "S3 bucket name used by the Terraform remote backend."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.terraform_state_bucket_name))
    error_message = "terraform_state_bucket_name must be compatible with S3 bucket naming rules."
  }
}

variable "terraform_lock_table_name" {
  type        = string
  description = "DynamoDB table name used by the Terraform remote backend for state locking."

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{3,255}$", var.terraform_lock_table_name))
    error_message = "terraform_lock_table_name must be a valid DynamoDB table name."
  }
}

variable "cloudfront_4xx_error_rate_threshold" {
  type        = number
  description = "CloudFront 4xx error rate percentage threshold for the monitoring alarm."
  default     = 5
}

variable "cloudfront_5xx_error_rate_threshold" {
  type        = number
  description = "CloudFront 5xx error rate percentage threshold for the monitoring alarm."
  default     = 1
}

variable "cloudwatch_alarm_actions" {
  type        = list(string)
  description = "SNS topic ARNs or other CloudWatch alarm action ARNs invoked when CloudFront alarms enter ALARM state."
  default     = []
}

variable "cloudwatch_ok_actions" {
  type        = list(string)
  description = "SNS topic ARNs or other CloudWatch alarm action ARNs invoked when CloudFront alarms return to OK state."
  default     = []
}
