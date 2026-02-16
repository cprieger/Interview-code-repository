# GEMINI.md: AI-Assisted Development Workflow

This project utilized **Gemini 3 Flash** to implement a "Principal-grade" observability stack.

## 🚀 Key Iterations & Automation
* **Toolchain Parity:** Aligned the `Dockerfile` with **Go 1.23** to match the local development environment, resolving build-time version mismatches.
* **Observability Provisioning:** Automated Grafana dashboard and datasource setup via YAML provisioning, ensuring a "batteries-included" experience upon launch.
* **Exact Path Routing:** Solved the Go 1.22 routing collision where the location parameter `{location}` was intercepting `/metrics` and `/health`.
* **Zero-Trust Testing:** Integrated `bootstrap.sh` to handle all cleanup, builds, and orchestration in a single command.

## 🧠 SRE Logic Applied
* **RED Method Dashboard:** Pre-configured Grafana to track Request Rate, Error Rate, and Duration (P99).
* **SLO-Based Alerting:** Defined Prometheus rules for high latency and error budget burn.
* **Structured Context:** JSON logging enriched with correlation IDs for seamless log-to-metric correlation.