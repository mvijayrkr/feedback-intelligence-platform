---
name: phase0-floci-foundation
description: Use when bootstrapping FLOCI, running Phase 0 Terraform, EKS, MSK, or fixing local-floci provider endpoint issues.
version: 1.0.0
---

# Phase 0 — FLOCI Foundation

## When to use

- User asks to bootstrap, run Phase 0, start FLOCI, or fix Terraform apply failures
- VPC/EC2 AuthFailure during `terraform apply`
- Setting up local EKS + MSK + RDS emulator stack

## Workflow

1. `export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-west-2`
2. `make floci-start` — must run before Terraform
3. `make bootstrap` or individual targets: `tf-init`, `tf-apply`, `k8s-config`, `topics`, `helm-install`, `verify`

## Terraform (local-floci)

- Path: `infra/terraform/envs/local-floci/`
- **All** AWS service endpoints must point to FLOCI, especially **ec2** for VPC/subnets/security groups
- If AuthFailure on ec2: add `ec2 = var.floci_endpoint` in `provider.tf` endpoints block

## Key outputs

```bash
cd infra/terraform/envs/local-floci && terraform output
```

- `kafka_bootstrap_brokers`
- `rds_endpoint` (host:port — port is often 7001)
- S3 bucket names

## Do not

- Run `terraform destroy` without explicit user request
- Commit `.env` or secrets
- Use real AWS credentials for local-floci env
