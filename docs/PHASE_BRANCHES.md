# Phase-wise Git branches

This repo is maintained **one phase per branch** so learners and contributors can check out exactly the code they need, run that phase, and move forward without wading through unfinished work.

## Branch strategy

Each phase branch is **cumulative** — it contains everything required to run that phase end-to-end (infra, Makefile targets, services, Helm, docs).

| Branch | Contains | Run after checkout |
|--------|----------|-------------------|
| `main` | Project overview, docs, scaffolding | Read-only; not meant for local deploy |
| `phase-0` | FLOCI + Terraform + EKS + MSK + Helm foundation | `make bootstrap` |
| `phase-1` | Phase 0 + ingestion (generator, producer/consumer jobs) | `make phase1` |
| `phase-2` | Phase 1 + data platform worker + dbt gold marts | `make phase2` |
| `dev` | Active development (may be ahead of latest phase branch) | Use phase targets as documented in `CLAUDE.md` |

Future phases follow the same pattern: `phase-3`, `phase-4`, etc.

## For users (execute a phase)

```bash
git clone <repo-url>
cd feedback-intelligence-platform

# Pick the phase you want to run
git checkout phase-1

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-west-2
cp .env.example .env

make doctor
make bootstrap    # if starting from phase-0 or first time
make phase1       # example for phase-1 branch
```

Use the branch that matches your goal — you do not need to merge branches locally; each phase branch should be runnable on its own.

## For maintainers (committing phase work)

**Rule:** land phase work on the matching branch only. Do not mix Phase 2 changes into `phase-1`.

### When a phase is complete

1. Ensure the phase passes its Make verify targets (`make verify`, `make phase1-verify`, etc.).
2. Commit on `dev` (or a short-lived feature branch), then merge or cherry-pick into the phase branch:
   ```bash
   git checkout phase-1
   git merge dev   # or cherry-pick specific commits
   git push -u origin phase-1
   ```
3. Tag optional release points: `git tag phase-1-v1.0.0 && git push origin phase-1-v1.0.0`
4. Update `CLAUDE.md` phase status table and this file if branch names change.

### Commit message convention

Use phase prefix in subject lines:

```
phase-0: add ec2 endpoint to local-floci provider
phase-1: fix ECR push and immutable job delete in Makefile
phase-2: deploy data-platform-worker with RDS port from terraform output
```

### What not to commit

- `.env` (secrets)
- `.terraform/`, `*.tfstate`
- Local Claude overrides (`.claude/settings.local.json`)

## Existing remote branches

| Remote branch | Notes |
|---------------|-------|
| `origin/phase0_1` | Legacy naming; superseded by `phase-0` / `phase-1` |
| `origin/dev` | Integration branch — sync with `phase-2` after phase releases |
| `origin/main` | Default branch |

## Local phase branches (created)

| Branch | Latest commit topic |
|--------|---------------------|
| `phase-0` | FLOCI foundation + Terraform + Helm base |
| `phase-1` | Phase 0 + ingestion workers |
| `phase-2` | Phase 1 + data platform + dbt |
| `dev` | Tracks latest `phase-2` for active development |

Push to share with learners:

```bash
git push -u origin phase-0 phase-1 phase-2 dev
```

## Claude Code

When asked to commit or prepare a phase release, read this file and:

1. Confirm which phase the changes belong to
2. Commit to the correct branch (or advise the user to checkout that branch first)
3. Never force-push phase branches shared with learners

See also: `CLAUDE.md` → **Phase branch workflow**.
