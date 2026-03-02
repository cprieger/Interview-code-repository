# ai/

Ollama HTTP client. Powers two game mechanics:

| Method | Trigger | Fallback |
|---|---|---|
| `GenerateRiddle(ctx)` | Sphinx encounter | Hardcoded riddle |
| `MonsterDialogue(ctx, name)` | Monster flavour text | Generic description |

## Model

Default: `llama3.2:1b` (small, fast, CPU-friendly). Swap via `OLLAMA_MODEL` env if desired.

## Fallback behaviour

If Ollama is unreachable (timeout, not running), both methods return valid responses with `fallback: true`.
The game **always works** without Ollama — riddles are just less dynamic.

## Metrics

Every request is observed:
```
m20_ai_requests_total{type="riddle", status="success|timeout|error"}
m20_ai_request_duration_seconds{type="riddle"}
```
