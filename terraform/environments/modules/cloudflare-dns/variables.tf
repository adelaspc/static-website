variable "zone_name" {
  type        = string
  description = "Cloudflare zone name that contains the DNS records."

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.zone_name))
    error_message = "zone_name must be a valid lowercase DNS zone name."
  }
}

variable "record_names" {
  type        = list(string)
  description = "DNS record names to point at CloudFront."

  validation {
    condition = alltrue([
      for name in var.record_names : can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", name))
    ])
    error_message = "Every record name must be a valid lowercase DNS name."
  }
}

variable "cloudfront_distribution_name" {
  type        = string
  description = "CloudFront distribution domain name used as the CNAME target."

  validation {
    condition     = can(regex("^[a-z0-9-]+\\.cloudfront\\.net$", var.cloudfront_distribution_name))
    error_message = "cloudfront_distribution_name must be a CloudFront distribution domain name."
  }
}

variable "ttl" {
  type        = number
  description = "TTL for DNS-only Cloudflare CNAME records."
  default     = 300

  validation {
    condition     = var.ttl >= 60 && var.ttl <= 86400
    error_message = "ttl must be between 60 and 86400 seconds."
  }
}
