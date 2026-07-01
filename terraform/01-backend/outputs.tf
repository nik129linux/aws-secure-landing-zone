output "aws_region" {
  value       = var.aws_region
  description = "AWS Region for the terraform state."
}

output "bucket_name" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "Bucket name for the terraform state."
}

output "bucket_arn" {
  value       = aws_s3_bucket.terraform_state.arn
  description = "Bucket ARN for the terraform state."
}

output "bucket_id" {
  value       = aws_s3_bucket.terraform_state.id
  description = "Bucket ID for the terraform state."
}
