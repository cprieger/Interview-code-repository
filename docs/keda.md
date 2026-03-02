# KEDA — Event-Driven Autoscaling

KEDA (Kubernetes Event-Driven Autoscaling) scales workloads based on **external events** (queues, streams, HTTP, etc.) rather than only CPU/memory.

## Why KEDA for This Project

Our weather service uses a **Redis queue**. When `chaos_test.sh` loads 800 jobs, the queue backs up. KEDA watches Redis list length and scales workers **before** the default 15–30s HPA poll would notice, letting us scale aggressively to meet demand.

## How It Works

1. **ScaledObject** targets the `weather-service` deployment.
2. **Trigger**: Redis list `weather:jobs` — scales when `LLEN weather:jobs > listLength * currentReplicas`.
3. KEDA creates and manages an HPA under the hood.
4. When the queue drains, KEDA scales down to `minReplicaCount`.

## Configuration

```yaml
# platform/local/k8s/weather-service/keda-scaledobject.yaml
triggers:
  - type: redis
    metadata:
      address: redis.default.svc.cluster.local:6379
      listName: weather:jobs
      listLength: "5"  # ~5 jobs per replica → add replica
```

## Demo on Kind

```bash
# 1. Create cluster, install KEDA
kind create cluster --name weather-sre
helm install keda kedacore/keda --namespace keda --create-namespace

# 2. Deploy Redis + weather-service
kubectl apply -f platform/local/k8s/weather-service/redis.yaml
kubectl apply -f platform/local/k8s/weather-service/weather-service.yaml
kubectl apply -f platform/local/k8s/weather-service/keda-scaledobject.yaml

# 3. Load queue
kubectl port-forward svc/weather-service 8080:8080 &
curl -X POST "http://localhost:8080/queue/load?count=500&chaos=true"

# 4. Watch scaling
kubectl get hpa -w
kubectl get pods -l app=weather-service -w
```

## Metrics

- `weather_queue_length` — Exposed by the service; Grafana dashboards use it.
- KEDA reads Redis `LLEN` directly; no Prometheus required for scaling.
