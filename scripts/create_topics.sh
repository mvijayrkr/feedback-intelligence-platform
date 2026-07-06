#!/usr/bin/env bash
set -euo pipefail

TF_DIR="infra/terraform/envs/local-floci"
BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-$(terraform -chdir="$TF_DIR" output -raw kafka_bootstrap_brokers 2>/dev/null || echo localhost:9092)}"

KAFKA_TOPICS_BIN="$(command -v kafka-topics || true)"
if [ -z "$KAFKA_TOPICS_BIN" ]; then
  KAFKA_TOPICS_BIN="$(command -v kafka-topics.sh || true)"
fi

if [ -z "$KAFKA_TOPICS_BIN" ]; then
  echo "⚠️ Kafka CLI not found. Runtime is FLOCI MSK, but local topic admin tool is missing."
  echo "   Install CLI only if needed: brew install kafka"
  exit 0
fi

echo "Kafka CLI: $KAFKA_TOPICS_BIN"
echo "Bootstrap: $BOOTSTRAP_SERVERS"

if echo "$BOOTSTRAP_SERVERS" | grep -E '^(172\.|10\.|192\.168\.)' >/dev/null; then
  echo "⚠️ Bootstrap address is internal to FLOCI/Docker: $BOOTSTRAP_SERVERS"
  echo "   Skipping host-side topic creation."
  echo "   Topics should be created from inside FLOCI/EKS or after exposing a host-accessible MSK listener."
  exit 0
fi

topics=("feedback.raw.events" "feedback.validated.events" "feedback.bronze.events" "feedback.silver.events" "feedback.gold.events" "feedback.dlq.events")

for topic in "${topics[@]}"; do
  "$KAFKA_TOPICS_BIN" --bootstrap-server "$BOOTSTRAP_SERVERS" --create --if-not-exists --topic "$topic" --partitions 3 --replication-factor 1 || {
    echo "⚠️ Topic creation failed for $topic. This is usually host reachability to FLOCI MSK."
    exit 0
  }
done

echo "✅ Kafka topics created or already exist"