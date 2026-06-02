data "cloudflare_zone" "this" {
  filter = {
    name = var.zone_name
  }
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_names[0]
  subject_alternative_names = slice(var.domain_names, 1, length(var.domain_names))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  validation_records = {
    for option in aws_acm_certificate.this.domain_validation_options : option.domain_name => {
      name    = trimsuffix(option.resource_record_name, ".")
      type    = option.resource_record_type
      content = trimsuffix(option.resource_record_value, ".")
    }
  }
}

resource "cloudflare_dns_record" "acm_validation" {
  for_each = local.validation_records

  zone_id = data.cloudflare_zone.this.id
  name    = each.value.name
  type    = each.value.type
  content = each.value.content
  ttl     = var.validation_record_ttl
  proxied = false
  comment = "Managed by Terraform. ACM DNS validation for ${each.key}."
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in cloudflare_dns_record.acm_validation : record.name]
}
