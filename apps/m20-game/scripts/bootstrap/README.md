# scripts/bootstrap/

`bootstrap.sh` — One-shot setup: build image, start services, health check, pull Ollama model.

```bash
./scripts/bootstrap/bootstrap.sh
```

What it does:
1. `docker compose build --no-cache`
2. `docker compose up -d`
3. Health-polls `http://localhost:8082/health` until ready
4. Pulls `llama3.2:1b` into Ollama if not already present (~800MB, first run only)
5. Prints service URLs

Subsequent runs skip the model pull (already cached in the `ollama-data` volume).
