#!/bin/bash
# Create a kind cluster for local K8s testing.
# Prerequisite: kind installed (brew install kind, or see https://kind.sigs.k8s.io)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KIND_CONFIG="${REPO_ROOT}/platform/local/kind/cluster-config.yaml"

echo "Creating kind cluster..."
kind create cluster --config "$KIND_CONFIG" --name weather-sre 2>/dev/null || true

echo ""
echo "Cluster ready. Next steps:"
echo "  1. Install metrics-server: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
echo "  2. Install KEDA: helm repo add kedacore https://kedacore.github.io/charts && helm install keda kedacore/keda --namespace keda --create-namespace"
echo "  3. Build and load image: cd apps/weather-service && docker build -t weather-service:latest . && kind load docker-image weather-service:latest --name weather-sre"
echo "  4. Deploy: kubectl apply -f platform/local/k8s/weather-service/"
