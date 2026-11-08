---
name: phase1-ingestion
description: Use when working on Phase 1 ingestion — data generator, MSK producer/consumer, ECR push, or ingestion Helm jobs.
version: 1.0.0
---

# Phase 1 — Data Ingestion

## When to use

- Deploy or debug `feedback-producer` / `feedback-consumer` jobs
- Generate dummy feedback data to S3
- Fix ImagePullBackOff on ingestion workers
- MSK/Kafka connectivity issues

## Workflow

```bash
make phase1-generate   # S3 dummy data
make phase1-push       # ECR — required before EKS deploy
make phase1-deploy
make phase1-verify
```

## Key paths

| Path | Role |
|------|------|
| `services/data-generator/` | Generates dummy feedback to S3 |
| `services/ingestion-worker/` | MSK producer + consumer |
| `infra/helm/feedback-platform/templates/phase1-*.yaml` | K8s Jobs |
| `shared/schemas/feedback_event.py` | Event schema |

## Rules

1. FLOCI EKS cannot see local Docker images — always `make phase1-push` before deploy
2. Kubernetes Jobs are immutable — delete job before Helm upgrade if template changes
3. Use `from shared.schemas.feedback_event import FeedbackEvent` in ingestion worker

## Debugging

```bash
make phase1-status
make phase1-logs
kubectl logs -n feedback job/feedback-producer
kubectl logs -n feedback job/feedback-consumer
```
