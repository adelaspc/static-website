variable "region" {
  type        = string
  description = "AWS region for the Terraform state backend resources."

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "The region must be a valid AWS region identifier, for example eu-central-1."
  }
}

variable "project" {
  type        = string
  description = "Project name used for naming and tagging backend resources."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.project))
    error_message = "The project value must use lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment name. This bootstrap stack supports only dev."
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This bootstrap stack supports only the dev environment."
  }
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name used for Terraform remote state."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be compatible with S3 bucket naming rules."
  }
}

variable "noncurrent_state_version_retention_days" {
  type        = number
  description = "Number of days to retain noncurrent Terraform state object versions."
  default     = 90

  validation {
    condition     = var.noncurrent_state_version_retention_days >= 30
    error_message = "noncurrent_state_version_retention_days must be at least 30 days."
  }
}
