provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway     = var.floci_endpoint
    cloudwatch     = var.floci_endpoint
    cloudwatchlogs = var.floci_endpoint
    ec2            = var.floci_endpoint
    ecr            = var.floci_endpoint
    eks            = var.floci_endpoint
    iam            = var.floci_endpoint
    kafka          = var.floci_endpoint
    rds            = var.floci_endpoint
    s3             = var.floci_endpoint
    secretsmanager = var.floci_endpoint
    sqs            = var.floci_endpoint
    sts            = var.floci_endpoint
  }
}