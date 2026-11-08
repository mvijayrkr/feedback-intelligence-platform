---
name: terraform-local-floci
description: Use when editing Terraform in infra/terraform/envs/local-floci, fixing provider endpoints, or reading FLOCI outputs for deploy configs.
version: 1.0.0
---

# Terraform — local-floci

## Path

`infra/terraform/envs/local-floci/`

## Provider rules

All AWS API calls must route to FLOCI emulator endpoint (`var.floci_endpoint`, typically `:4566`).

Required endpoints block must include at minimum:
- s3, ec2, eks, rds, kafka (msk), secretsmanager, iam, sts

**Common bug:** missing `ec2` endpoint causes real AWS AuthFailure on VPC resources.

## Workflow

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-west-2
make floci-start
cd infra/terraform/envs/local-floci
terraform init
terraform plan
terraform apply
```

## Outputs used by Makefile/Helm

```bash
terraform output -raw rds_endpoint      # host:port
terraform output -raw kafka_bootstrap_brokers
```

RDS port is embedded in `rds_endpoint` output — do not assume 5432.

## Safety

- Do not run `terraform destroy` unless user explicitly requests
- Do not commit `.terraform/` or `*.tfstate` (gitignored)
