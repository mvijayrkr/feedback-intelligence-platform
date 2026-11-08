---
description: Bootstrap Phase 0 — FLOCI foundation, Terraform, EKS, MSK, Helm
---

# Phase 0 — Foundation Bootstrap

Execute Phase 0 for the Feedback Intelligence Platform using Make targets. Read `CLAUDE.md` and follow these steps in order.

## Preconditions

1. Confirm `.env` exists (`cp .env.example .env` if missing)
2. Export FLOCI credentials:
   ```bash
   export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-west-2
   ```
3. Run `make doctor` and fix any missing tools

## Execute

```bash
make bootstrap
```

This runs: `doctor` → `floci-start` → `tf-init` → `tf-apply` → `k8s-config` → `topics` → `helm-install` → `verify`

## Terraform note

If `terraform apply` fails with AWS AuthFailure on VPC/EC2, ensure `infra/terraform/envs/local-floci/provider.tf` routes **ec2** to `var.floci_endpoint`, then re-run after `make floci-start`.

## Verify success

```bash
make verify
kubectl get nodes
kubectl get ns feedback
```

Report outputs from `terraform output` (kafka brokers, rds endpoint, bucket names) and any failures with suggested fixes.
