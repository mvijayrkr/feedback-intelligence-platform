# Phase 0 Correction Notes

Your latest run shows Terraform is now working and created 12 local FLOCI resources.

The remaining errors are caused by the guide trying to do too much in `make bootstrap`.

## What worked

Terraform created:

- S3 buckets
- SQS DLQ
- ECR repositories
- IAM role
- CloudWatch log groups
- Secrets Manager secret containers

## What failed and why

### 1. `put-secret-value` failed

Terraform created the secret containers, but the Makefile tried to add values later with AWS CLI.

Correct fix: create secret values in Terraform using `aws_secretsmanager_secret_version`.

Copy `secret_versions.tf` into:

```bash
infra/terraform/envs/local-floci/secret_versions.tf
```

Then run:

```bash
terraform -chdir=infra/terraform/envs/local-floci apply -auto-approve
```

### 2. EKS / kubectl failed

No EKS cluster was created in the current Terraform plan.

So this should not be part of the default `make bootstrap`.

### 3. Kafka topics failed

`kafka-topics.sh` is not installed and no Kafka/MSK broker is running yet.

So this should not be part of the default `make bootstrap`.

### 4. Helm failed

Helm requires a reachable Kubernetes cluster. Since no EKS/Kubernetes cluster exists yet, Helm install must be optional.

## Correct Phase 0 model

`make bootstrap` should verify only the core foundation:

```bash
make bootstrap
```

Optional runtime checks:

```bash
make runtime-check
```

Full verification:

```bash
make verify-all
```
