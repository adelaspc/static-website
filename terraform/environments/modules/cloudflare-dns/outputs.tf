output "zone_id" {
  value = data.cloudflare_zone.this.id
}

output "record_names" {
  value = [for record in cloudflare_dns_record.cloudfront : record.name]
}

output "record_ids" {
  value = [for record in cloudflare_dns_record.cloudfront : record.id]
}
