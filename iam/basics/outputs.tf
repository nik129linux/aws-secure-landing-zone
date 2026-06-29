output "provider_region" {
  value = var.region
}

output "bucket_name" {
  value = data.aws_s3_bucket.nico-day-2-bucket.bucket
}

output "user_name" {
  value = aws_iam_user.nico-day-3.name
}

output "user_arn" {
  value = aws_iam_user.nico-day-3.arn
}
