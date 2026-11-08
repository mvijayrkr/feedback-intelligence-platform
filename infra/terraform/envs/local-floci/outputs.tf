output "local_aws_endpoint" {
  value = var.floci_endpoint
}

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "msk_cluster_name" {
  value = aws_msk_cluster.main.cluster_name
}

output "raw_bucket" {
  value = aws_s3_bucket.raw.bucket
}

output "processed_bucket" {
  value = aws_s3_bucket.processed.bucket
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}

output "dlq_url" {
  value = aws_sqs_queue.feedback_dlq.url
}

output "api_log_group" {
  value = aws_cloudwatch_log_group.api.name
}

output "kafka_bootstrap_brokers" {
  value = try(aws_msk_cluster.main.bootstrap_brokers, "localhost:9092")
}
output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "rds_db_name" {
  value = aws_db_instance.postgres.db_name
}

output "rds_username" {
  value = aws_db_instance.postgres.username
}

output "rds_secret_name" {
  value = "/feedback/local/db_password"
}