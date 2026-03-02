# Weather Service K8s Manifests

## Overview

- **redis.yaml** — Redis deployment + service (message queue)
- **weather-service.yaml** — Weather service deployment + service
- **keda-scaledobject.yaml** — KEDA scales on Redis list length (`weather:jobs`)
- **hpa.yaml** — CPU-based HPA (1–3 replicas). **Do not apply with KEDA** — KEDA manages HPA for the same deployment.
- **vpa.yaml** — VPA in `Off` mode (recommendations only)

## KEDA vs HPA

- **With KEDA**: Apply redis, weather-service, keda-scaledobject. Skip hpa.yaml.
- **Without KEDA**: Apply redis, weather-service, hpa.yaml.

## Prerequisites

- kind cluster (or any K8s)
- metrics-server (for HPA CPU)
- KEDA (for ScaledObject)
- VPA components (for vpa.yaml)

## Apply

```bash
kubectl apply -f redis.yaml
kubectl apply -f weather-service.yaml
kubectl apply -f keda-scaledobject.yaml
# Optional: kubectl apply -f vpa.yaml
```

## Load Queue for KEDA Demo

```bash
kubectl port-forward svc/weather-service 8080:8080 &
curl -X POST "http://localhost:8080/queue/load?count=500&chaos=true"
kubectl get hpa -w  # KEDA-created HPA
kubectl get pods -l app=weather-service -w
```
