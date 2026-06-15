output "cloudfront_4xx_alarm_name" {
  description = "Name of the CloudWatch alarm monitoring the CloudFront 4xx error rate."
  value       = aws_cloudwatch_metric_alarm.cloudfront_4xx_error_rate.alarm_name
}

output "cloudfront_5xx_alarm_name" {
  description = "Name of the CloudWatch alarm monitoring the CloudFront 5xx error rate."
  value       = aws_cloudwatch_metric_alarm.cloudfront_5xx_error_rate.alarm_name
}
