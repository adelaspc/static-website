resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx_error_rate" {
  alarm_name          = "${var.project}-${var.environment}-cloudfront-4xx-error-rate"
  alarm_description   = "CloudFront 4xx error rate is above ${var.cloudfront_4xx_error_rate_threshold}%."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = var.cloudfront_4xx_error_rate_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_error_rate" {
  alarm_name          = "${var.project}-${var.environment}-cloudfront-5xx-error-rate"
  alarm_description   = "CloudFront 5xx error rate is above ${var.cloudfront_5xx_error_rate_threshold}%."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = var.cloudfront_5xx_error_rate_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }
}
