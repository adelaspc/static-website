variable "project" {
  type        = string
  description = "Project name used for naming and tagging resources."
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
}

variable "bucket_regional_domain_name" {
  type        = string
  description = "Regional S3 bucket domain name used as the CloudFront origin."
}

variable "price_class" {
  type        = string
  description = "CloudFront price class."
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "aliases" {
  type        = list(string)
  description = "Alternative domain names for the CloudFront distribution."
  default     = []
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN in us-east-1 for CloudFront aliases."

  validation {
    condition     = can(regex("^arn:aws:acm:us-east-1:[0-9]{12}:certificate/[0-9a-f-]+$", var.acm_certificate_arn))
    error_message = "The ACM certificate ARN must be issued in us-east-1 for CloudFront."
  }
}

variable "minimum_protocol_version" {
  type        = string
  description = "Minimum TLS protocol version for CloudFront viewers."
  default     = "TLSv1.2_2021"
}

variable "logging_bucket_domain_name" {
  type        = string
  description = "S3 bucket domain name where CloudFront standard logs are delivered."
}

variable "logging_prefix" {
  type        = string
  description = "Prefix for CloudFront standard logs."
  default     = "cloudfront/"
}

variable "custom_error_response_page_path" {
  type        = string
  description = "Page returned by CloudFront for custom 403 and 404 responses."
  default     = "/index.html"
}

variable "custom_error_response_ttl" {
  type        = number
  description = "Minimum TTL in seconds for CloudFront custom error responses."
  default     = 0

  validation {
    condition     = var.custom_error_response_ttl >= 0
    error_message = "custom_error_response_ttl must be greater than or equal to 0."
  }
}
