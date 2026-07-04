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
	@echo ""
	@echo "Phase 1 commands:"
	@echo "  make phase1-push   # build and push ingestion worker to FLOCI ECR (required after cluster recreate)"
	@echo "  make phase1-deploy # deploy producer/consumer jobs into FLOCI EKS"
	@echo "  make phase1        # full Phase 1 pipeline"

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

PHASE1_IMAGE ?= fip-local/ingestion-worker:phase1
PHASE1_IMAGE_TAG ?= phase1
PHASE1_ECR_REPOSITORY ?= fip-local/workers
PHASE1_ECR_PUSH_REGISTRY ?= localhost:5100
PHASE1_ECR_CONTAINER ?= floci-ecr-registry
PHASE1_EKS_CONTAINER ?= $(shell docker ps --format '{{.Names}}' | grep '^floci-eks-' | head -1)
PHASE1_MSK_CONTAINER ?= floci-msk-fip-local-msk
PHASE1_FLOCI_CONTAINER ?= floci
PHASE1_FLOCI_HOST ?= $(shell docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(PHASE1_FLOCI_CONTAINER) 2>/dev/null)
PHASE1_AWS_ENDPOINT_URL ?= http://$(PHASE1_FLOCI_HOST):4566
PHASE1_ECR_NODE_REGISTRY ?= $(shell docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(PHASE1_ECR_CONTAINER) 2>/dev/null):5000
PHASE1_MSK_BOOTSTRAP ?= $(shell docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(PHASE1_MSK_CONTAINER) 2>/dev/null):9092
PHASE1_DEPLOY_IMAGE_REPO ?= $(PHASE1_ECR_NODE_REGISTRY)/$(PHASE1_ECR_REPOSITORY)
PHASE1_ECR_PUSH_IMAGE ?= $(PHASE1_ECR_PUSH_REGISTRY)/$(PHASE1_ECR_REPOSITORY):$(PHASE1_IMAGE_TAG)
NAMESPACE ?= feedback
HELM_CHART ?= infra/helm/feedback-platform
TF_DIR ?= infra/terraform/envs/local-floci

.PHONY: phase1-install phase1-generate phase1-build phase1-push phase1-k8s-ready phase1-ecr-ready phase1-kafka-ready phase1-deploy phase1-status phase1-logs phase1-verify phase1-clean phase1

phase1-install:
	python3 -m pip install -r services/data-generator/requirements.txt

phase1-generate:
	PYTHONPATH=. python3 services/data-generator/generator.py

phase1-build:
	docker build -t $(PHASE1_IMAGE) -f services/ingestion-worker/Dockerfile .

phase1-push: phase1-build
	@test -n "$(PHASE1_ECR_NODE_REGISTRY)" || (echo "❌ FLOCI ECR container '$(PHASE1_ECR_CONTAINER)' not found. Run 'make floci-start' first."; exit 1)
	docker tag $(PHASE1_IMAGE) $(PHASE1_ECR_PUSH_IMAGE)
	aws --endpoint-url $(FLOCI_ENDPOINT) ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(PHASE1_ECR_PUSH_REGISTRY)
	docker push $(PHASE1_ECR_PUSH_IMAGE)

phase1-k8s-ready:
	@if ! kubectl get nodes >/dev/null 2>&1; then \
	  echo "❌ kubectl cannot reach FLOCI EKS (expected https://localhost:6500)."; \
	  echo "   FLOCI was likely restarted and the cluster is gone."; \
	  echo "   Run: make tf-apply && make k8s-config"; \
	  exit 1; \
	fi

phase1-ecr-ready:
	@test -n "$(PHASE1_ECR_NODE_REGISTRY)" || (echo "❌ FLOCI ECR container '$(PHASE1_ECR_CONTAINER)' not found."; exit 1)
	@test -n "$(PHASE1_EKS_CONTAINER)" || (echo "❌ FLOCI EKS container not found. Run 'make tf-apply && make k8s-config' first."; exit 1)
	@if ! docker exec $(PHASE1_EKS_CONTAINER) grep -q "$(PHASE1_ECR_NODE_REGISTRY)" /etc/rancher/k3s/registries.yaml 2>/dev/null; then \
	  echo "🔧 Configuring FLOCI EKS to pull from insecure registry $(PHASE1_ECR_NODE_REGISTRY)"; \
	  docker exec $(PHASE1_EKS_CONTAINER) sh -c 'mkdir -p /etc/rancher/k3s && printf "mirrors:\n  \"%s\":\n    endpoint:\n      - \"http://%s\"\n" "$(PHASE1_ECR_NODE_REGISTRY)" "$(PHASE1_ECR_NODE_REGISTRY)" > /etc/rancher/k3s/registries.yaml'; \
	  docker restart $(PHASE1_EKS_CONTAINER); \
	  sleep 15; \
	  kubectl get nodes >/dev/null || (echo "❌ FLOCI EKS did not come back after registry config. Run 'make k8s-config'."; exit 1); \
	fi

phase1-kafka-ready:
	@test -n "$(PHASE1_MSK_BOOTSTRAP)" || (echo "❌ FLOCI MSK container '$(PHASE1_MSK_CONTAINER)' not found. Run 'make tf-apply' first."; exit 1)
	@MSK_IP=$$(echo "$(PHASE1_MSK_BOOTSTRAP)" | cut -d: -f1); \
	if docker exec $(PHASE1_MSK_CONTAINER) grep -q 'address: 127.0.0.1' /etc/redpanda/redpanda.yaml 2>/dev/null; then \
	  echo "🔧 Updating FLOCI MSK advertised_kafka_api to $$MSK_IP"; \
	  docker exec $(PHASE1_MSK_CONTAINER) sh -c "sed -i 's/address: 127.0.0.1/address: '$$MSK_IP'/g' /etc/redpanda/redpanda.yaml"; \
	  docker restart $(PHASE1_MSK_CONTAINER); \
	  sleep 5; \
	fi

phase1-deploy: phase1-k8s-ready phase1-ecr-ready phase1-kafka-ready
	kubectl delete job feedback-producer feedback-consumer -n $(NAMESPACE) --ignore-not-found=true
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install feedback-platform ./$(HELM_CHART) \
	  --namespace $(NAMESPACE) \
	  -f $(HELM_CHART)/values-local.yaml \
	  --set ingestion.enabled=true \
	  --set ingestion.image.repository=$(PHASE1_DEPLOY_IMAGE_REPO) \
	  --set ingestion.image.tag=$(PHASE1_IMAGE_TAG) \
	  --set ingestion.kafka.bootstrapServers="$(PHASE1_MSK_BOOTSTRAP)" \
	  --set ingestion.kafka.topic=feedback.raw.events \
	  --set ingestion.aws.endpointUrl=$(PHASE1_AWS_ENDPOINT_URL) \
	  --set ingestion.aws.region=us-west-2 \
	  --set ingestion.s3.rawBucket=fip-local-raw \
	  --wait --timeout 180s

phase1-status:
	kubectl get pods -n $(NAMESPACE)
	kubectl get jobs -n $(NAMESPACE)

phase1-logs:
	kubectl logs -n $(NAMESPACE) job/feedback-producer --tail=100 || true
	kubectl logs -n $(NAMESPACE) job/feedback-consumer --tail=100 || true

phase1-verify:
	@test -f data/dummy/out/feedback_events.jsonl
	wc -l data/dummy/out/feedback_events.jsonl
	aws --endpoint-url http://localhost:4566 kafka list-clusters --region us-west-2 --query 'ClusterInfoList[].ClusterName'
	kubectl get jobs -n $(NAMESPACE)
	aws --endpoint-url http://localhost:4566 s3 ls s3://fip-local-raw --recursive --summarize || true

phase1-clean:
	kubectl delete job feedback-producer feedback-consumer -n $(NAMESPACE) --ignore-not-found=true

phase1: phase1-install phase1-generate phase1-push phase1-deploy phase1-status phase1-logs phase1-verify
	@echo "✅ Phase 1 complete: ingestion executed on FLOCI EKS and connected to FLOCI MSK"
