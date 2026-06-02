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
  description = "Deployment environment name."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment must be one of: dev, staging, prod."
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

variable "lock_table_name" {
  type        = string
  description = "DynamoDB table name used for Terraform state locking."

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{3,255}$", var.lock_table_name))
    error_message = "lock_table_name must be a valid DynamoDB table name."
  }
}
