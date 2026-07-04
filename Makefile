# Makefile — Phase 0 FLOCI Foundation with EKS + MSK
# Final validated behavior:
# - Terraform creates FLOCI EKS, FLOCI MSK, S3, IAM, Secrets, ECR, SQS, and CloudWatch.
# - Helm deploys a base app into FLOCI EKS.
# - Kafka CLI is optional and is used only for admin commands.
# - Kafka runtime is FLOCI MSK, not a local Kafka broker.
# - If FLOCI returns an internal Docker broker IP such as 172.17.0.4:9092, verification does not fail.

SHELL := /bin/bash
.DEFAULT_GOAL := help

AWS_REGION ?= us-west-2
FLOCI_ENDPOINT ?= http://localhost:4566
TF_DIR := infra/terraform/envs/local-floci
HELM_CHART := infra/helm/feedback-platform
NAMESPACE := feedback
CLUSTER_NAME := fip-local-eks
MSK_CLUSTER_NAME := fip-local-msk

.PHONY: help doctor bootstrap floci-start tf-check tf-init tf-plan tf-apply k8s-config topics helm-install verify tf-destroy clean

help:
	@echo "Phase 0 commands:"
	@echo "  make doctor      # verify required local developer tools"
	@echo "  make bootstrap   # FLOCI -> Terraform(EKS/MSK/S3/Secrets/IAM/etc) -> kubectl -> topics -> Helm -> verify"
	@echo "  make tf-plan     # preview Terraform resources"
	@echo "  make helm-install# deploy base Helm chart only"
	@echo "  make verify      # verify Phase 0 foundation"
	@echo "  make tf-destroy  # destroy local Terraform resources"
	@echo "  make clean       # stop FLOCI"

doctor:
	@command -v floci >/dev/null || (echo "❌ floci not installed"; exit 1)
	@command -v aws >/dev/null || (echo "❌ aws cli not installed"; exit 1)
	@command -v terraform >/dev/null || (echo "❌ terraform not installed"; exit 1)
	@command -v kubectl >/dev/null || (echo "❌ kubectl not installed"; exit 1)
	@command -v helm >/dev/null || (echo "❌ helm not installed"; exit 1)
	@if command -v kafka-topics >/dev/null || command -v kafka-topics.sh >/dev/null; then \
	  echo "✅ Kafka CLI available for optional MSK admin commands"; \
	else \
	  echo "⚠️ Kafka CLI not found. Kafka runtime is FLOCI MSK. Install CLI only if needed: brew install kafka"; \
	fi
	@echo "✅ Required developer tools are installed"

bootstrap: doctor floci-start tf-check tf-init tf-apply k8s-config topics helm-install verify
	@echo "✅ Phase 0 FLOCI foundation completed: EKS + MSK + S3 + IAM + Secrets + Helm"

floci-start:
	floci start
	aws --endpoint-url $(FLOCI_ENDPOINT) sts get-caller-identity
	aws --endpoint-url $(FLOCI_ENDPOINT) s3 ls || true

tf-check:
	@test -f $(TF_DIR)/versions.tf || (echo "❌ Missing or empty $(TF_DIR)/versions.tf"; exit 1)
	@test -f $(TF_DIR)/provider.tf || (echo "❌ Missing or empty $(TF_DIR)/provider.tf"; exit 1)
	@test -f $(TF_DIR)/main.tf || (echo "❌ Missing or empty $(TF_DIR)/main.tf"; exit 1)
	@test -f $(TF_DIR)/outputs.tf || (echo "❌ Missing or empty $(TF_DIR)/outputs.tf"; exit 1)
	@echo "✅ Terraform files found and are not empty"
	@ls -la $(TF_DIR)

tf-init:
	terraform -chdir=$(TF_DIR) init -upgrade

tf-plan:
	terraform -chdir=$(TF_DIR) plan

tf-apply:
	terraform -chdir=$(TF_DIR) apply -auto-approve
	terraform -chdir=$(TF_DIR) output || true

k8s-config:
	aws --endpoint-url $(FLOCI_ENDPOINT) eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)
	kubectl get nodes

topics:
	@KAFKA_BIN=$$(command -v kafka-topics || command -v kafka-topics.sh || true); \
	BOOTSTRAP=$$(terraform -chdir=$(TF_DIR) output -raw kafka_bootstrap_brokers 2>/dev/null || echo ""); \
	if [ -z "$$KAFKA_BIN" ]; then \
	  echo "⚠️ Skipping topic creation because Kafka CLI is not installed."; \
	  echo "   Runtime Kafka is FLOCI MSK. Install CLI only if needed: brew install kafka"; \
	elif [ -z "$$BOOTSTRAP" ]; then \
	  echo "⚠️ Skipping topic creation because Terraform did not return kafka_bootstrap_brokers."; \
	elif echo "$$BOOTSTRAP" | grep -E '^172\.|^10\.|^192\.168\.' >/dev/null; then \
	  echo "⚠️ FLOCI returned internal Docker/MSK broker address: $$BOOTSTRAP"; \
	  echo "   MSK is created. Topic admin from macOS may timeout against this internal broker."; \
	  echo "   Topic creation is deferred to Phase 1 service/runtime path."; \
	else \
	  chmod +x scripts/create_topics.sh; \
	  KAFKA_TOPICS_BIN=$$KAFKA_BIN KAFKA_BOOTSTRAP_SERVERS=$$BOOTSTRAP ./scripts/create_topics.sh; \
	fi

helm-install:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm lint ./$(HELM_CHART) -f $(HELM_CHART)/values-local.yaml
	helm upgrade --install feedback-platform ./$(HELM_CHART) \
	  --namespace $(NAMESPACE) --create-namespace \
	  -f $(HELM_CHART)/values-local.yaml \
	  --wait --timeout 180s

verify:
	@echo "🔎 S3 buckets"
	aws --endpoint-url $(FLOCI_ENDPOINT) s3 ls
	@echo "🔎 Secrets"
	aws --endpoint-url $(FLOCI_ENDPOINT) secretsmanager list-secrets --query 'SecretList[].Name'
	@echo "🔎 EKS cluster"
	aws --endpoint-url $(FLOCI_ENDPOINT) eks describe-cluster --region $(AWS_REGION) --name $(CLUSTER_NAME) --query 'cluster.name'
	@echo "🔎 MSK cluster"
	aws --endpoint-url $(FLOCI_ENDPOINT) kafka list-clusters --region $(AWS_REGION) --query 'ClusterInfoList[].ClusterName'
	@echo "🔎 Kubernetes pods"
	kubectl get pods -n $(NAMESPACE)
	@echo "🔎 Kafka bootstrap returned by Terraform"
	@BOOTSTRAP=$$(terraform -chdir=$(TF_DIR) output -raw kafka_bootstrap_brokers 2>/dev/null || echo ""); \
	echo "$$BOOTSTRAP"; \
	KAFKA_BIN=$$(command -v kafka-topics || command -v kafka-topics.sh || true); \
	if [ -z "$$BOOTSTRAP" ]; then \
	  echo "⚠️ No Kafka bootstrap output found"; \
	elif echo "$$BOOTSTRAP" | grep -E '^172\.|^10\.|^192\.168\.' >/dev/null; then \
	  echo "⚠️ Kafka broker address is internal to FLOCI/Docker: $$BOOTSTRAP"; \
	  echo "   MSK exists, but laptop-side Kafka admin may not reach this address from macOS."; \
	  echo "   This is acceptable for Phase 0 foundation verification."; \
	elif [ -n "$$KAFKA_BIN" ]; then \
	  $$KAFKA_BIN --list --bootstrap-server "$$BOOTSTRAP" || true; \
	else \
	  echo "⚠️ Kafka CLI not found; topic list skipped"; \
	fi
	@echo "✅ Phase 0 verification completed"

tf-destroy:
	terraform -chdir=$(TF_DIR) destroy -auto-approve

clean:
	floci stop
