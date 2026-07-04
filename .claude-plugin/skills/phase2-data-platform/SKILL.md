---
name: phase2-data-platform
description: Use when working on Phase 2 data platform worker, dbt gold marts, RDS loading, DQ rules, or NLP enrichment.
version: 1.0.0
---

# Phase 2 — Data Platform + dbt

## When to use

- Deploy/debug `data-platform-worker` or `dbt-runner` jobs
- RDS connectivity, port 7001 issues
- dbt models in `analytics/dbt/fip_analytics/`
- DQ rules or NLP enrichment in worker

## Workflow

```bash
make phase2-push
make phase2-deploy-worker
make phase2-deploy-dbt
make phase2-verify
```

## Critical deploy rules

Phase 2 deploys must:
1. Delete existing `feedback-producer` and `feedback-consumer` jobs
2. Set Helm values: `ingestion.producer.enabled=false`, `ingestion.consumer.enabled=false`
3. Use ECR image tags from `make phase2-push`
4. Use in-cluster FLOCI bridge IPs for S3/RDS (from `terraform output`), not localhost
5. Use RDS port from `terraform output -raw rds_endpoint` (typically **7001**)

## Key paths

| Path | Role |
|------|------|
| `services/data-platform-worker/worker.py` | Bronze→Silver→Gold pipeline |
| `services/data-platform-worker/dq_rules.py` | Data quality |
| `services/data-platform-worker/nlp_enrichment.py` | NLP enrichment |
| `analytics/dbt/fip_analytics/` | dbt marts |
| `infra/helm/feedback-platform/templates/phase2-*.yaml` | K8s Jobs |

## Python imports

Worker uses local imports (folder has hyphens):
```python
from dq_rules import ...
from nlp_enrichment import ...
```

## Performance note

If worker is slow, check `requirements.txt` for unused `torch`/`transformers` — remove if NLP doesn't need them locally.
