output "certificate_arn" {
  value = aws_acm_certificate_validation.this.certificate_arn
}

output "validation_record_names" {
  value = [for record in cloudflare_dns_record.acm_validation : record.name]
}
