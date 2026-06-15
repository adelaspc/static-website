output "certificate_arn" {
  description = "ARN of the validated ACM certificate for the configured domain names."
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "validation_record_names" {
  description = "DNS record names created in Cloudflare for ACM validation."
  value       = [for record in cloudflare_dns_record.acm_validation : record.name]
}
