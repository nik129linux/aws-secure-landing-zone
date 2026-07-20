terraform {
  backend "s3" {

  }
}

provider "aws" {
  region = var.aws_region
}
data "aws_caller_identity" "current" {}

data "terraform_remote_state" "cloudwatch_logs" {
  backend = "s3"
  config = {
    bucket = "nico-day-roadmap-day4-terraform-state"
    key    = "cloudtrail-logs/terraform.tfstate"
    region = var.aws_region
  }
}
resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts-topic"
}

resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.email_target
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.security_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudwatch.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.security_alerts.arn
    }]
  })
}

# Alarma 1: Uso de Cuenta Root (CIS 1.1)
resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  name           = "RootUsage"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
  log_group_name = data.terraform_remote_state.cloudwatch_logs.outputs.trail_logs_group_name

  metric_transformation {
    name          = "RootUsageCount"
    namespace     = "CloudTrailMetrics"
    value         = "1"
    default_value = 0
  }
}
resource "aws_cloudwatch_log_metric_filter" "no_mfa_login" {
  name           = "NoMFALogin"
  pattern        = "{ $.eventName = \"ConsoleLogin\" && $.additionalEventData.MFAUsed != \"Yes\" }"
  log_group_name = data.terraform_remote_state.cloudwatch_logs.outputs.trail_logs_group_name

  metric_transformation {
    name          = "NoMFALoginCount"
    namespace     = "CloudTrailMetrics"
    value         = "1"
    default_value = 0
  }
}
resource "aws_cloudwatch_metric_alarm" "root_usage" {
  alarm_name          = "Critical-RootAccountUsage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = aws_cloudwatch_log_metric_filter.root_usage.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.root_usage.metric_transformation[0].namespace
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "no_mfa_login" {
  alarm_name          = "Warning-ConsoleLoginWithoutMFA"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = aws_cloudwatch_log_metric_filter.no_mfa_login.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.no_mfa_login.metric_transformation[0].namespace
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"
}
