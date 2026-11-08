#!/usr/bin/env bash
# SessionStart hook — inject FLOCI env reminder for Claude Code sessions in FIP repo.
set -euo pipefail

cat <<'EOF'
FIP session reminder:
- Export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-west-2 before kubectl/terraform/aws
- Run `make floci-start` before Terraform apply
- Read CLAUDE.md for phase rules (ECR push, immutable K8s Jobs, RDS port from terraform output)
- Prefer `make` targets over ad-hoc helm/kubectl
EOF
