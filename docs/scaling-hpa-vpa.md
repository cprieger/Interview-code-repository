# HPA & VPA — Pod Autoscaling

## Horizontal Pod Autoscaler (HPA)

Scales **replicas** based on metrics (CPU, memory, custom).

- **Min/max replicas**: 1–3 in our config.
- **Target**: 70% CPU utilization.
- **Note**: When using KEDA, do **not** apply a separate HPA for the same deployment — KEDA manages one internally.

### HPA-Only Mode (no KEDA)

```bash
kubectl apply -f platform/local/k8s/weather-service/redis.yaml
kubectl apply -f platform/local/k8s/weather-service/weather-service.yaml
kubectl apply -f platform/local/k8s/weather-service/hpa.yaml
```

## Vertical Pod Autoscaler (VPA)

Recommends or applies **resource requests/limits** per container.

- **Modes**: `Off` (recommend only), `Recreate`, `Auto`.
- Our config: `Off` — view recommendations without changing pods.
- To apply: set `updatePolicy.updateMode: Recreate` or `Auto`.

### VPA Commands

```bash
kubectl apply -f platform/local/k8s/weather-service/vpa.yaml
kubectl describe vpa weather-service-vpa  # See recommendations
```

## Learning Path

1. Run with **HPA only** — load CPU, watch `kubectl get hpa`.
2. Run with **KEDA only** — load queue, watch scaling.
3. Enable **VPA** in recommend mode — inspect suggested resources.
