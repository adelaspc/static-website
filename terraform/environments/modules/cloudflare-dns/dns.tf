data "cloudflare_zone" "this" {
  filter = {
    name = var.zone_name
  }
}

resource "cloudflare_dns_record" "cloudfront" {
  for_each = toset(var.record_names)

  zone_id = data.cloudflare_zone.this.id
  name    = each.value
  type    = "CNAME"
  content = var.cloudfront_distribution_name
  ttl     = var.ttl
  proxied = false
  comment = "Managed by Terraform. Points to the CloudFront distribution."
}
