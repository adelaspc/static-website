locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
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

  logging_config {
    bucket          = var.logging_bucket_domain_name
    include_cookies = false
    prefix          = var.logging_prefix
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = var.custom_error_response_page_path
    error_caching_min_ttl = var.custom_error_response_ttl
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
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

  tags = local.common_tags
}
