---
description: Commit or prepare a phase release on the correct Git branch
---

# Phase branch commit workflow

The maintainer commits **phase-wise to separate branches** so learners can checkout and execute one phase at a time.

Read **`docs/PHASE_BRANCHES.md`** before any git work.

## Steps

1. Ask which phase the changes belong to (0, 1, 2, …).
2. Confirm the user is on the correct branch (`phase-0`, `phase-1`, `phase-2`, or `dev` for integration).
3. Run the phase verify target before committing:
   - Phase 0: `make verify`
   - Phase 1: `make phase1-verify`
   - Phase 2: `make phase2-verify`
4. Commit with phase prefix: `phase-N: short description`
5. Push to `origin phase-N` — never force-push shared phase branches.

## Do not commit

- `.env`, credentials, tfstate
- `.terraform/`, `.claude/settings.local.json`

## User-facing checkout (remind if helpful)

```bash
git checkout phase-1
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-west-2
make phase1
```
