data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

locals {
  log_delivery_source_name      = substr("${var.project}-${var.environment}-cloudfront-access-logs", 0, 60)
  log_delivery_destination_name = substr("${var.project}-${var.environment}-cloudfront-s3", 0, 60)
}

resource "aws_cloudfront_origin_access_control" "static_website" {
  name                              = "${var.project}-${var.environment}-oac"
  description                       = "Origin access control for ${var.project} ${var.environment}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.project}-${var.environment}-security-headers"
  comment = "Security headers for ${var.project} ${var.environment}"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
  }
}

resource "aws_cloudfront_distribution" "static_website" {
  #checkov:skip=CKV_AWS_86:Access logging is enabled through CloudFront Standard Logging v2 delivery resources; this check recognizes only the legacy logging_config block.
  #checkov:skip=CKV_AWS_68:AWS WAF is intentionally omitted for this low-traffic portfolio environment to avoid fixed and request-based cost.
  #checkov:skip=CKV2_AWS_47:This exception follows the documented decision not to provision a WAF web ACL for the portfolio environment.
  #checkov:skip=CKV_AWS_310:A single private S3 origin is sufficient for the documented portfolio availability target; origin failover is not claimed.
  #checkov:skip=CKV_AWS_374:The public portfolio site is intentionally available globally, so no geographic allowlist or denylist is configured.
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.price_class
  aliases             = var.aliases

  origin {
    domain_name              = var.bucket_regional_domain_name
    origin_id                = "s3-${var.project}-${var.environment}"
    origin_access_control_id = aws_cloudfront_origin_access_control.static_website.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${var.project}-${var.environment}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = var.custom_error_response_page_path
    error_caching_min_ttl = var.custom_error_response_ttl
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = var.custom_error_response_page_path
    error_caching_min_ttl = var.custom_error_response_ttl
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    minimum_protocol_version = var.minimum_protocol_version
    ssl_support_method       = "sni-only"
  }
}

resource "aws_cloudwatch_log_delivery_source" "cloudfront" {
  provider = aws.us_east_1

  name         = local.log_delivery_source_name
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.static_website.arn
}

resource "aws_cloudwatch_log_delivery_destination" "cloudfront_s3" {
  provider = aws.us_east_1

  name          = local.log_delivery_destination_name
  output_format = "w3c"

  delivery_destination_configuration {
    destination_resource_arn = var.logging_bucket_arn
  }
}

resource "aws_cloudwatch_log_delivery" "cloudfront_s3" {
  provider = aws.us_east_1

  delivery_source_name     = aws_cloudwatch_log_delivery_source.cloudfront.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cloudfront_s3.arn
}
