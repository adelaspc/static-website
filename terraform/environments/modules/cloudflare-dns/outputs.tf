output "zone_id" {
  description = "Cloudflare zone ID containing the website DNS records."
  value       = data.cloudflare_zone.this.id
}

output "record_names" {
  description = "DNS record names that point to the CloudFront distribution."
  value       = [for record in cloudflare_dns_record.cloudfront : record.name]
}

output "record_ids" {
  description = "Cloudflare IDs of the DNS records that point to CloudFront."
  value       = [for record in cloudflare_dns_record.cloudfront : record.id]
}
