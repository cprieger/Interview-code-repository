# GEMINI.md: AI-Assisted SRE Workflow

## 🚀 Project Status: Maximum Observability & Reliability
This project has evolved from a basic API into a fully instrumented, resilience-tested microservice. Below is a summary of the architectural challenges resolved and the SRE principles applied.

### 🛠️ Technical Reconciliations
1.  **Docker Layer Caching & Stale Builds:**
    * **Problem:** Code changes to `main.go` were not reflecting in the running container due to aggressive Docker caching of the `COPY . .` layer.
    * **Resolution:** Implemented a `bootstrap.sh` protocol using `--no-cache` and strict volume pruning to guarantee atomic, fresh deployments.
    * **Verification:** Added a Startup Banner (`!!! BUILD: ELEGANT MIDDLEWARE MODE !!!`) to logs to prove code freshness.

2.  **Routing Version Compatibility:**
    * **Problem:** Go 1.22+ wildcard routing (`/weather/{id}`) caused 404s in older container runtimes.
    * **Resolution:** Refactored to a **Universal Prefix Matcher** (`strings.HasPrefix`) strategy. This makes the routing logic robust across any Go version (1.18 - 1.23).

3.  **Context Propagation & Fault Injection:**
    * **Problem:** Chaos triggers were being lost between the Middleware and the HTTP Client.
    * **Resolution:** Standardized on **Literal String Keys** (`"chaos_trigger"`) for `context.Context` values to eliminate package-boundary type mismatches.
    * **Enhancement:** Implemented a **Dual-Vector Trigger** (Headers + Query Params) to bypass potential proxy stripping.

### 🧠 SRE Principles Applied
* **Observability-Driven Development (ODD):** We didn't just fix bugs; we added metrics *first*. We now track:
    * **Golden Signals:** Latency (P99), Traffic (RPS), Errors (5xx Rate).
    * **System Saturation:** Heap Memory, Goroutine Count, CPU Usage.
    * **Client Behavior:** 4xx Error Rates (to detect bad requests vs. server faults).
* **Deterministic Chaos:** Replaced "random" failures with controlled, synthetic fault injection (`?chaos=true`) to mathematically verify alerting pipelines.
* **Infrastructure as Code:** All dashboards, datasources, and alert rules are provisioned via config files, not manual UI clicking.

### 📊 Final Architecture
* **Edge:** Nginx Control Plane (Port 8081).
* **Middleware:** SRE Interceptor (Tracing, Logging, Fault Injection).
* **Core:** Go Weather Service (Port 8080).
* **Monitoring:** Prometheus (Port 9090) + Grafana (Port 3000).

---
*Generated via AI Collaboration Session - Feb 2026*