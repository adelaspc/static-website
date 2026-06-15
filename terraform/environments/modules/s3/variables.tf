variable "project" {
  type        = string
  description = "Project name used for naming and tagging resources."
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
}

variable "bucket_name" {
  type        = string
  description = "Environment-specific component used with project to build the final S3 bucket names."
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Number of days to retain noncurrent versions of website objects."
  default     = 30

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "noncurrent_version_expiration_days must be at least 1."
  }
}

variable "cloudfront_log_retention_days" {
  type        = number
  description = "Number of days to retain CloudFront access logs."
  default     = 90

  validation {
    condition     = var.cloudfront_log_retention_days >= 1
    error_message = "cloudfront_log_retention_days must be at least 1."
  }
}
