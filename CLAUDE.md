# Feedback Intelligence Platform (FIP)

Production-grade, AI-native feedback intelligence platform for restaurants. Local runtime uses **FLOCI** (AWS-compatible emulator) + **Terraform** + **EKS** + **MSK** + **Helm**.

## Current implementation status

| Phase | Status | Key paths |
|-------|--------|-----------|
| 0 — FLOCI foundation | Implemented | `infra/terraform/envs/local-floci/`, `Makefile` (bootstrap targets) |
| 1 — Ingestion | Implemented | `services/ingestion-worker/`, `services/data-generator/`, Phase 1 Helm jobs |
| 2 — Data platform | In progress | `services/data-platform-worker/`, `analytics/dbt/fip_analytics/`, Phase 2 Helm jobs |
| 3+ — RAG / agents | Planned | See `docs/fip-htmls-interactive-final/` |

## Repository layout

```
apps/           → api, web, agent-service, voice-service (mostly scaffold)
services/       → workers: data-generator, ingestion-worker, data-platform-worker, …
shared/         → schemas, config, auth, logging
data/           → dummy sources, dbt, sql
analytics/      → dbt project (Phase 2 marts)
infra/          → terraform (local-floci), helm (feedback-platform)
docs/           → phase course HTML guides (source of truth for build steps)
```

## Non-negotiable rules

1. **Never commit secrets** — use `.env` (gitignored) and FLOCI Secrets Manager paths from `.env.example`.
2. **FLOCI before Terraform** — run `make floci-start` before any `terraform apply`. Provider must include `ec2 = var.floci_endpoint` in `provider.tf`.
3. **Kubernetes Jobs are immutable** — delete existing Jobs before Helm upgrades that change pod templates. Phase 2 deploys must disable Phase 1 ingestion jobs (`ingestion.producer.enabled=false`, `ingestion.consumer.enabled=false`).
4. **ECR push before EKS deploy** — FLOCI EKS cannot see local Docker images. Use `make phase1-push` / `make phase2-push` before deploy targets.
5. **In-cluster AWS/RDS endpoints** — use FLOCI Docker bridge IPs (`PHASE1_FLOCI_HOST`, `PHASE1_ECR_NODE_REGISTRY`, `RDS_HOST` from `terraform output`), not `localhost`, inside Kubernetes Jobs.
6. **RDS port** — FLOCI RDS listens on port from `terraform output -raw rds_endpoint` (typically `7001`, not `5432`).

## Environment setup (every shell)

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-west-2
cp .env.example .env   # if missing
```

## Make targets (primary workflow)

```bash
make doctor              # verify local tools
make bootstrap           # Phase 0 full pipeline
make phase1              # generate → push → deploy ingestion jobs
make phase2              # push → deploy worker → deploy dbt → verify
make phase2-deploy-worker
make phase2-deploy-dbt
make verify              # Phase 0 checks
```

## Helm chart

- Chart: `infra/helm/feedback-platform/`
- Values: `infra/helm/feedback-platform/values-local.yaml`
- Namespace: `feedback`
- Phase 1 templates: `phase1-producer-job.yaml`, `phase1-consumer-job.yaml`
- Phase 2 templates: `phase2-data-platform-job.yaml`, `phase2-dbt-runner-job.yaml`

## Python conventions

- Ingestion worker imports: `from shared.schemas.feedback_event import FeedbackEvent`
- Data platform worker: local imports (`from dq_rules import …`) when run as `python services/data-platform-worker/worker.py`
- Service folders use **hyphens** (`data-platform-worker`); do not use invalid module names with hyphens in import paths

## Terraform (local-floci)

- Env: `infra/terraform/envs/local-floci/`
- Provider endpoints must route **all** AWS services to FLOCI, especially **ec2** (VPC/subnets/SG)
- Key outputs: `kafka_bootstrap_brokers`, `rds_endpoint`, bucket names

## Phase branch workflow

**Maintainer intent:** code is committed **phase-wise on separate branches** so users can checkout one branch and run that phase without unrelated WIP.

| Branch | Run |
|--------|-----|
| `phase-0` | `make bootstrap` |
| `phase-1` | `make phase1` |
| `phase-2` | `make phase2` |
| `dev` | active integration (may be ahead of phase branches) |

Full branching rules, commit conventions, and user checkout steps: **`docs/PHASE_BRANCHES.md`**.

When committing or preparing a phase release:

1. Put changes only on the branch for that phase (do not mix phase-2 work into `phase-1`).
2. Use commit subjects like `phase-1: fix ECR push before deploy`.
3. Verify with the phase Make targets before pushing.
4. Do not commit `.env`, tfstate, or local Claude overrides.

## When editing

- Match existing Makefile / Helm / Terraform patterns before introducing new abstractions
- Phase course HTML under `docs/fip-htmls-interactive-final/fip-course-v3-step-by-step/` is the build spec — keep Makefile snippets in sync
- Minimize scope: one phase at a time, no unrelated refactors
- Prefer `make` targets over ad-hoc kubectl/helm commands

## Claude Code assets in this repo

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | This file — always loaded project context |
| `.claude/settings.json` | Permissions and FLOCI env defaults |
| `.claude/commands/` | Slash commands (`/phase0`, `/phase1`, `/phase2`, …) |
| `.claude-plugin/` | Bundled plugin: skills, hooks, agents |
| `.claude-plugin/skills/` | Phase-specific agent skills |

Install bundled plugin (optional, for skills/hooks/agents):

```bash
claude plugin add ./.claude-plugin
```

## Docs reference

- Product overview: `README.md`
- Phase 0: `docs/fip-htmls-interactive-final/fip-phase0-foundation-interactive-final-fixed-order.html`
- Phase 1: `docs/fip-htmls-interactive-final/fip-course-v3-step-by-step/fip-phase1-data-ingestion-eks-msk-final.html`
- Phase 2: `docs/fip-htmls-interactive-final/Final/fip-phase2-data-platform-gold-dbt-editable-final.html`
