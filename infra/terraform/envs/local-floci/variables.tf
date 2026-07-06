variable "aws_region" {
  description = "Local FLOCI AWS-compatible region"
  type        = string
  default     = "us-west-2"
}

variable "floci_endpoint" {
  description = "FLOCI local AWS endpoint"
  type        = string
  default     = "http://localhost:4566"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "local"
}

variable "tenant_id" {
  description = "Default tenant used for tutorial data"
  type        = string
  default     = "curry_bowl_express"
}

variable "eks_cluster_name" {
  description = "FLOCI EKS cluster name"
  type        = string
  default     = "fip-local-eks"
}

variable "msk_cluster_name" {
  description = "FLOCI MSK cluster name"
  type        = string
  default     = "fip-local-msk"
}

variable "rds_db_name" {
  type    = string
  default = "fip"
}

variable "rds_username" {
  type    = string
  default = "fip_user"
}

variable "rds_password" {
  type      = string
  default   = "fip_password"
  sensitive = true
}