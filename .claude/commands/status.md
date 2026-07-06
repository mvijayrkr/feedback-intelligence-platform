---
description: Check FIP cluster health — jobs, pods, terraform outputs, phase status
---

# FIP Platform Status Check

Gather current platform health and report a concise status summary.

## Setup

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-west-2
```

## Commands to run

```bash
make doctor 2>/dev/null || true
kubectl get nodes 2>/dev/null || echo "kubectl not configured"
kubectl get jobs,pods -n feedback 2>/dev/null || echo "feedback namespace missing"
make phase1-status 2>/dev/null || true
make phase2-status 2>/dev/null || true
cd infra/terraform/envs/local-floci && terraform output 2>/dev/null || echo "terraform outputs unavailable"
```

## Report format

Provide:

1. **Phase 0** — FLOCI/Terraform/EKS healthy or not
2. **Phase 1** — producer/consumer job status
3. **Phase 2** — data-platform-worker and dbt-runner status
4. **Blockers** — ImagePullBackOff, CrashLoopBackOff, pending jobs
5. **Next action** — single recommended Make target to fix top blocker

Do not run destructive commands (`terraform destroy`, force push) unless explicitly asked.
