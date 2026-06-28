locals {
  project = "feedback-intelligence-platform"

  tags = {
    Project     = local.project
    Environment = var.environment
    Tenant      = var.tenant_id
    ManagedBy   = "terraform"
  }
}

# -------------------------------------------------------------------
# Network foundation required by EKS and MSK
# -------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "fip-local-vpc"
  })
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = merge(local.tags, {
    Name = "fip-local-private-a"
  })
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = merge(local.tags, {
    Name = "fip-local-private-b"
  })
}

resource "aws_security_group" "platform" {
  name        = "fip-local-platform-sg"
  description = "Local platform security group for FLOCI EKS and MSK"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow local platform internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.20.0.0/16", "127.0.0.1/32"]
  }

  egress {
    description = "Allow all local outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "fip-local-platform-sg"
  })
}
resource "aws_db_subnet_group" "main" {
  name       = "fip-local-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = merge(local.tags, {
    Name = "fip-local-db-subnet-group"
  })
}

resource "aws_db_instance" "postgres" {
  identifier             = "fip-local-postgres"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = var.rds_db_name
  username               = var.rds_username
  password               = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.platform.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = merge(local.tags, {
    Name = "fip-local-postgres"
  })
}


# -------------------------------------------------------------------
# IAM roles for FLOCI EKS
# -------------------------------------------------------------------

resource "aws_iam_role" "eks_cluster_role" {
  name = "fip-local-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role" "app_role" {
  name = "fip-local-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

# -------------------------------------------------------------------
# FLOCI EKS
# -------------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.29"

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.platform.id]
  }

  tags = local.tags
}

# -------------------------------------------------------------------
# FLOCI MSK / Kafka
# -------------------------------------------------------------------

resource "aws_msk_cluster" "main" {
  cluster_name           = var.msk_cluster_name
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.platform.id]
  }

  tags = local.tags
}

# -------------------------------------------------------------------
# S3 buckets
# -------------------------------------------------------------------

resource "aws_s3_bucket" "raw" {
  bucket = "fip-local-raw"
  tags   = local.tags
}

resource "aws_s3_bucket" "processed" {
  bucket = "fip-local-processed"
  tags   = local.tags
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "fip-local-artifacts"
  tags   = local.tags
}

# -------------------------------------------------------------------
# SQS DLQ
# -------------------------------------------------------------------

resource "aws_sqs_queue" "feedback_dlq" {
  name                      = "fip-local-feedback-dlq"
  message_retention_seconds = 1209600
  tags                      = local.tags
}

# -------------------------------------------------------------------
# ECR repositories
# -------------------------------------------------------------------

resource "aws_ecr_repository" "api" {
  name                 = "fip-local/api"
  image_tag_mutability = "MUTABLE"
  tags                 = local.tags
}

resource "aws_ecr_repository" "workers" {
  name                 = "fip-local/workers"
  image_tag_mutability = "MUTABLE"
  tags                 = local.tags
}

# -------------------------------------------------------------------
# Secrets Manager
# -------------------------------------------------------------------

resource "aws_secretsmanager_secret" "openai_api_key" {
  name = "/feedback/local/openai_api_key"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "openai_api_key_value" {
  secret_id     = aws_secretsmanager_secret.openai_api_key.id
  secret_string = "sk-dummy-local-key-replace-in-prod"
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "/feedback/local/jwt_secret"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret_value" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = "local-jwt-secret-replace-in-prod"
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "/feedback/local/db_password"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "db_password_value" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = "local-db-password-replace-in-prod"
}

# -------------------------------------------------------------------
# CloudWatch Logs
# -------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "api" {
  name              = "/fip/local/api"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "ingestion" {
  name              = "/fip/local/ingestion"
  retention_in_days = 7
  tags              = local.tags
}