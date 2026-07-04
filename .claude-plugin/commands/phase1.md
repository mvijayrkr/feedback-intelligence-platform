---
description: Run Phase 1 — generate dummy data, push images to FLOCI ECR, deploy ingestion jobs
---

# Phase 1 — Data Ingestion (EKS + MSK)

Execute Phase 1 ingestion pipeline. Phase 0 must be complete.

## Preconditions

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-west-2
make verify
```

## Execute full pipeline

```bash
make phase1
```

Or step by step:

```bash
make phase1-install
make phase1-generate
make phase1-push          # build + push to FLOCI ECR (required before deploy)
make phase1-deploy
make phase1-status
make phase1-verify
```

## Rules

- **ECR push before deploy** — FLOCI EKS cannot pull local-only Docker images
- Jobs: `feedback-producer`, `feedback-consumer` in namespace `feedback`
- Helm chart: `infra/helm/feedback-platform/`
- Worker code: `services/ingestion-worker/`, `services/data-generator/`

## Troubleshooting

- ImagePullBackOff → run `make phase1-push` then `make phase1-deploy`
- Job immutable error → delete existing job before helm upgrade
- Kafka not ready → `make phase1-kafka-ready`

Report job status, pod logs (`make phase1-logs`), and verification results.
