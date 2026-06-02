output "cloudfront_4xx_alarm_name" {
  value = aws_cloudwatch_metric_alarm.cloudfront_4xx_error_rate.alarm_name
}

output "cloudfront_5xx_alarm_name" {
  value = aws_cloudwatch_metric_alarm.cloudfront_5xx_error_rate.alarm_name
}
