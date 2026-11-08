---
name: helm-kubernetes-deploy
description: Use when deploying or upgrading FIP Helm chart, fixing immutable Job errors, or debugging pods in feedback namespace.
version: 1.0.0
---

# Helm + Kubernetes Deploy (FIP)

## Chart location

- Chart: `infra/helm/feedback-platform/`
- Values: `infra/helm/feedback-platform/values-local.yaml`
- Namespace: `feedback`

## Immutable Job pattern

Kubernetes Jobs cannot be patched in place. Before Helm upgrade that changes pod spec:

```bash
kubectl delete job -n feedback feedback-producer feedback-consumer --ignore-not-found
kubectl delete job -n feedback data-platform-worker dbt-runner --ignore-not-found
```

Makefile deploy targets handle this — prefer `make phase1-deploy`, `make phase2-deploy-worker`, etc.

## Common failures

| Symptom | Fix |
|---------|-----|
| ImagePullBackOff | Run phase push target, verify ECR registry in values |
| Job already exists | Delete job, redeploy |
| CrashLoopBackOff | Check logs; verify RDS port and FLOCI host IPs |
| Pending pods | Check node resources, image pull secrets |

## Status commands

```bash
kubectl get jobs,pods -n feedback
kubectl logs -n feedback job/<job-name> --tail=100
helm list -n feedback
helm history feedback-platform -n feedback
```

## Env required

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-west-2
```
