# FIP Platform Plugin

Claude Code plugin for the Feedback Intelligence Platform. Provides phase workflows, deploy skills, safety hooks, and specialized agents.

## Install

From the repository root:

```bash
claude plugin add ./.claude-plugin
```

Then restart Claude Code or start a new session.

## Components

| Directory | Purpose |
|-----------|---------|
| `commands/` | Slash commands: `/phase0`, `/phase1`, `/phase2`, `/status`, `/help` |
| `skills/` | Auto-activated phase and infra skills |
| `agents/` | Deploy and Terraform subagents |
| `hooks/` | SessionStart FLOCI env reminder |

## Project context

Always read `CLAUDE.md` at the repo root first. This plugin supplements that file with executable workflows.
