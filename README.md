Since I can't generate a direct file download for you, I’m providing the **README.md** in a single, clean code block below. You can click the "Copy" button in the top right of the block and save it as `README.md` in your project root.

This version is specifically crafted to address the **Principal SRE** requirements, highlighting **Observability**, **Reliability**, and **Operational Excellence**.


# Weather Alert Service

A production-ready Go backend service designed with a focus on **Operational Excellence**, **High Reliability**, and **Comprehensive Observability**.



## 🚀 Architecture & Philosophy
[cite_start]This service is built using a clean, layered architecture to ensure maintainability and testability[cite: 18].
* [cite_start]**Defensive Engineering:** Every external call is wrapped in a retry mechanism with exponential backoff and explicit context-based timeouts[cite: 46, 47].
* [cite_start]**The RED Method:** Instrumented with Prometheus to track **R**ate, **E**rrors, and **D**uration for all public endpoints[cite: 32, 34].
* [cite_start]**Cache-Aside Pattern:** Implements an in-memory cache to reduce upstream pressure and improve latency, including operational metrics to monitor cache efficiency[cite: 26, 48].

## 🛠 Prerequisites
* [cite_start]**Go 1.22+**: Core programming language[cite: 4].
* [cite_start]**Make**: For build and test automation[cite: 56].
* **Docker**: Recommended for running sidecar services like Prometheus.

## 🚦 Getting Started
1. **Initialize and Build:**
   ```bash
   make build

```

2. **Run the Service:**
```bash
# Replace with your actual key or use the mock default
WEATHER_API_KEY="your_api_key" make run

```


3. **Test the Endpoints:**
* 
**Weather:** `curl http://localhost:8080/weather/austin` 


* 
**Health:** `curl http://localhost:8080/health` 


* 
**Metrics:** `curl http://localhost:8080/metrics` 





## 📊 Observability & Metrics

The service exposes metrics at `/metrics` in a Prometheus-compatible format.

### Key Metrics Tracked:

| Metric Name | Type | Purpose |
| --- | --- | --- |
| `weather_service_http_requests_total` | Counter | Tracks request volume and error rates (RED: Rate/Errors).

 |
| `weather_service_http_request_duration_seconds` | Histogram | Tracks request latency percentiles (RED: Duration).

 |
| `weather_service_cache_hits_total` | Counter | Monitors cache efficiency and upstream cost.

 |

### Alerting Strategy

The included `alert_rules.yml` defines critical SRE alerts for paging with services like PagerDuty:

* **High Error Rate (Critical):** Paging alert if  of requests fail over a 5-minute window.
* **Latency Breach (Warning):** Warning if the **P99** latency exceeds .
* **Low Cache Hit Rate (Info):** Notifies when the cache is not providing expected offload for the upstream API.

## 🛡 Reliability Patterns

* 
**Graceful Shutdown:** Listens for `SIGINT`/`SIGTERM` and allows active requests time to finish before exiting.


* 
**Correlation IDs:** Every request is assigned a unique UUID (returned in the `X-Correlation-ID` header) to allow for request tracing across logs.


* 
**Structured Logging:** All logs are in JSON format, enriched with service context and trace IDs for ELK/Loki ingestion.
