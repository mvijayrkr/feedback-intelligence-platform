---
description: Show FIP Claude Code commands and workflow overview
---

# FIP Platform Help

Explain the Feedback Intelligence Platform Claude Code setup to the user.

## Project context

- Read `CLAUDE.md` at repo root — always-loaded operational guide
- Phase build specs: `docs/fip-htmls-interactive-final/`

## Slash commands

| Command | Purpose |
|---------|---------|
| `/phase0` | Bootstrap FLOCI + Terraform + EKS + Helm foundation |
| `/phase1` | Data generation, ECR push, ingestion job deploy |
| `/phase2` | Data platform worker + dbt runner deploy |
| `/status` | Check cluster jobs, pods, and phase health |
| `/phase-commit` | Commit phase work to the correct Git branch |
| `/help` | This help |

## Phase branches

Code is committed **one phase per branch** so learners can checkout and run easily:

```bash
git checkout phase-0   # make bootstrap
git checkout phase-1   # make phase1
git checkout phase-2   # make phase2
```

See `docs/PHASE_BRANCHES.md` for full rules.

## Required shell env (every session)

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-west-2
```

## Plugin install (optional, for skills/hooks/agents)

```bash
claude plugin add ./.claude-plugin
```

## Key Make targets

```bash
make doctor
make bootstrap      # Phase 0
make phase1         # Phase 1 full pipeline
make phase2         # Phase 2 full pipeline
make verify
```
