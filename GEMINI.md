# GEMINI.md: AI-Assisted Development Workflow

This project was built using an **AI-First** development methodology, utilizing **Gemini 3 Flash** to accelerate scaffolding and observability design.

## 🤖 AI Usage Disclosure
As encouraged by the assessment guidelines, AI was used for:
* **Boilerplate Generation:** Rapidly scaffolding the Go project structure and server configurations.
* **SRE Best Practices:** Validating Prometheus metric naming and alerting rule syntax.
* **Documentation:** Generating high-quality onboarding for reviewers.

## 🛠 Human-in-the-Loop Refinements
While AI generated the base logic, the following refinements were manually guided:
1. **Context Management:** Ensuring `r.Context()` propagates through the client to respect timeouts.
2. **Custom Status Tracking:** Implementing the `statusWriter` wrapper to capture HTTP status codes for Prometheus.
3. **Defensive Configurations:** Fine-tuning server timeouts to production-standard values.