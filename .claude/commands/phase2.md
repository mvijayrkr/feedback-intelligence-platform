---
description: Run Phase 2 — data platform worker, dbt runner, gold layer marts
---

# Phase 2 — Data Platform + dbt

Execute Phase 2 data platform pipeline. Phase 0 and Phase 1 data in S3 should exist.

## Preconditions

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-west-2
```

## Execute full pipeline

```bash
make phase2
```

Or step by step:

```bash
make phase2-install
make phase2-push
make phase2-deploy-worker
make phase2-deploy-dbt
make phase2-status
make phase2-verify
```

## Critical rules

1. **Push before deploy** — `make phase2-push` builds and pushes worker + dbt images to FLOCI ECR
2. **Disable Phase 1 jobs** — deploy targets delete `feedback-producer`/`feedback-consumer` and set `ingestion.producer.enabled=false`, `ingestion.consumer.enabled=false`
3. **RDS port** — use `terraform output -raw rds_endpoint` (typically port **7001**, not 5432)
4. **In-cluster endpoints** — use FLOCI bridge IPs from Makefile/terraform output, not `localhost`

## Key paths

- Worker: `services/data-platform-worker/`
- dbt: `analytics/dbt/fip_analytics/`
- Helm jobs: `phase2-data-platform-job.yaml`, `phase2-dbt-runner-job.yaml`

## Troubleshooting

- ImagePullBackOff → `make phase2-push` then redeploy
- Worker slow → check if torch/transformers are needed; trim `requirements.txt` if not
- dbt job failed → `kubectl logs -n feedback job/dbt-runner`

Report worker progress, dbt run status, and RDS connectivity.
