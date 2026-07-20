output "bucket_id" {
  value       = aws_s3_bucket.baseline.id
  description = "S3 bucket ID for the S3 baseline."
}

output "bucket_arn" {
  value       = aws_s3_bucket.baseline.arn
  description = "S3 bucket ARN for the S3 baseline."
}
