variable "project" {
  type        = string
  description = "Project name used for naming and tagging resources."
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
}

variable "cloudfront_distribution_id" {
  type        = string
  description = "CloudFront distribution ID to monitor."
}

variable "cloudfront_4xx_error_rate_threshold" {
  type        = number
  description = "CloudFront 4xx error rate percentage threshold."
  default     = 5

  validation {
    condition     = var.cloudfront_4xx_error_rate_threshold > 0 && var.cloudfront_4xx_error_rate_threshold <= 100
    error_message = "cloudfront_4xx_error_rate_threshold must be between 0 and 100."
  }
}

variable "cloudfront_5xx_error_rate_threshold" {
  type        = number
  description = "CloudFront 5xx error rate percentage threshold."
  default     = 1

  validation {
    condition     = var.cloudfront_5xx_error_rate_threshold > 0 && var.cloudfront_5xx_error_rate_threshold <= 100
    error_message = "cloudfront_5xx_error_rate_threshold must be between 0 and 100."
  }
}

variable "alarm_actions" {
  type        = list(string)
  description = "SNS topic ARNs or other CloudWatch alarm action ARNs invoked when alarms enter ALARM state."
  default     = []
}

variable "ok_actions" {
  type        = list(string)
  description = "SNS topic ARNs or other CloudWatch alarm action ARNs invoked when alarms return to OK state."
  default     = []
}
