output "trail_logs_group_arn" {
  value = aws_cloudwatch_log_group.trail_logs.arn
}
output "trail_logs_group_name" {
  value = aws_cloudwatch_log_group.trail_logs.name
}
output "cloudtrail_to_cw_role_arn" {
  value = aws_iam_role.cloudtrail_to_cw.arn
}
#cloud_watch_log_group_arn     = "${aws_cloudwatch_log_group.trail_logs.arn}:*"
#cloud_watch_log_role_arn      = aws_iam_role.cloudtrail_to_cw.arn

