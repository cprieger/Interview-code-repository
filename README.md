# Weather Service SRE Edition 🌩️

A production-grade Go microservice demonstrating **Site Reliability Engineering (SRE)** best practices: Observability, Chaos Engineering, and Infrastructure as Code.

## 🚀 Quick Start (The "One-Click" Deploy)

We use a unified bootstrap protocol to clean, build, and verify the entire stack.

```bash
# 1. Make the script executable
chmod +x scripts/bootstrap/bootstrap.sh

# 2. Launch the stack (run from project root)
./scripts/bootstrap/bootstrap.sh
```

Once the script completes, open the **Control Plane**:
👉 **[http://localhost:8081](http://localhost:8081)**

## 🏗️ Architecture

The system is composed of four Docker containers orchestrated via Compose:

| Service | Port | Description |
| :--- | :--- | :--- |
| **Weather API** | `8080` | Go-based microservice with SRE Middleware. |
| **Prometheus** | `9090` | Metrics scraper with 5s resolution & Alert Rules. |
| **Grafana** | `3000` | Visualization with pre-provisioned Golden Signal dashboards. |
| **Dashboard UI** | `8081` | Nginx-based central hub for navigation. |

## 💥 Chaos Engineering

This service has built-in **Fault Injection** capabilities to test resilience and alerting.

### Triggering a Fault
You can force a **500 Internal Server Error** (simulating an upstream outage) without bringing down the container:

* **Method A (Query Param):**
    `GET http://localhost:8080/weather/lubbock?chaos=true`
* **Method B (Header):**
    `curl -H "X-Chaos-Mode: true" http://localhost:8080/weather/lubbock`

### Running the Validation Suite
We include a script that generates traffic patterns (Normal, 404s, and 500s) to prove observability:

```bash
./scripts/chaos_test/chaos_test.sh
```

## 📊 Observability & Alerts

We track the **Four Golden Signals** plus Runtime Metrics.

### 🚨 Alert Rules (`prometheus/alert_rules.yml`)
* **`API_Server_Errors_High`**: >10% of requests are 5xx errors.
* **`API_Client_Errors_High`**: >10% of requests are 4xx errors.
* **`API_Latency_High`**: P99 Latency exceeds 500ms.
* **`System_Memory_High`**: Heap usage exceeds 50MB.
* **`System_Goroutines_High`**: Goroutine count spike detection.

### 📈 Grafana Dashboards
* **Global Error Rate %**: The "Oh No" graph.
* **Throughput (RPS)**: Traffic volume.
* **Latency Heatmap**: P99 vs P50 distribution.
* **Runtime Stats**: Memory & CPU saturation.

## 📂 Project Structure

```text
├── cmd/server/         # Application Entrypoint (Middleware & Routing)
├── internal/weather/   # Business Logic (Client & Caching)
├── prometheus/         # Alert Rules & Scrape Configs
├── grafana/            # JSON Dashboards & Datasource Provisioning
├── dashboard/          # HTML/CSS for the Control Plane UI
└── scripts/            # Shell scripts (each with its own README)
    ├── bootstrap/      # Deployment automation (clean build + health check)
    ├── chaos_test/     # SRE validation suite (4xx/5xx traffic)
    └── unit_test/      # Go reliability test (chaos vs cache priority)
```
