# The Pantheon — Dev Team Agents

Nine specialized AI agents living in `.claude/agents/`. They auto-load from the repo via Claude Code's native sub-agent system — no copy-paste needed.

## How to Use

```
/agents              # Browse and invoke any agent
```

Or ask naturally:
> "Have Iris review the game UI"
> "Ask Hephaestus to add the combat endpoint"
> "Get Hades to audit our dependencies"

Claude auto-delegates based on context. The pantheon is always available.

## The Pantheon

| Agent | File | Domain |
|---|---|---|
| 🌈 Iris | `iris.md` | Frontend, jQuery, game UI, PWA |
| 🔨 Hephaestus | `hephaestus.md` | Go, game engine, API, persistence |
| ⚡ Hermes | `hermes.md` | API contracts, Go middleware, integration |
| ⚖️ Themis | `themis.md` | ISTQB testing, Go tests, quality |
| 👁️ Argus | `argus.md` | SRE, observability, Prometheus, Grafana |
| 🔥 Prometheus | `prometheus.md` | K8s, Docker, OpenTofu, AWS, CI/CD, cost |
| 🖤 Hades | `hades.md` | OWASP security, supply chain, CVEs |
| 🌅 Eos | `eos.md` | PWA, Capacitor.js, Android, mobile |
| 🗺️ Atlas | `atlas.md` | Roadmap, Android launch, cost governance |

## Team Philosophy: "Everything Has an Experience"

Every layer has a designed experience — errors, APIs, UIs, backends, pipelines, dashboards. Not an afterthought.

- Errors explain what happened and what to do next
- READMEs are in every directory, concise and actionable
- Dashboards tell you system health in 3 seconds
- Code is discoverable at every layer

## Project Context

See `CLAUDE.md` at repo root. Agents contain full project context and current sprint focus.

```
apps/weather-service/   ← SRE demo (Go, live)
apps/m20-game/          ← M20 RPG game (Go, in progress)
platform/local/k8s/     ← Kubernetes manifests
.claude/agents/         ← The pantheon lives here
```
