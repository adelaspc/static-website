variable "zone_name" {
  type        = string
  description = "Cloudflare zone name used for ACM DNS validation records."

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.zone_name))
    error_message = "zone_name must be a valid lowercase DNS zone name."
  }
}

variable "domain_names" {
  type        = list(string)
  description = "Domain names covered by the ACM certificate. The first value is the primary domain; remaining values are SANs."

  validation {
    condition = length(var.domain_names) > 0 && alltrue([
      for name in var.domain_names : can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", name))
    ])
    error_message = "domain_names must contain at least one valid lowercase DNS name."
  }
}

variable "validation_record_ttl" {
  type        = number
  description = "TTL for ACM DNS validation CNAME records in Cloudflare."
  default     = 300

  validation {
    condition     = var.validation_record_ttl >= 60 && var.validation_record_ttl <= 86400
    error_message = "validation_record_ttl must be between 60 and 86400 seconds."
  }
}
