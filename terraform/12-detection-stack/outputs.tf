output "detector_id" {
  value       = aws_guardduty_detector.main.id
  description = "The ID of the GuardDuty detector"
}
