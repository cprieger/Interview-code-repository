# Scripts

Shell scripts for deploying, testing, and validating the Weather Service SRE stack. Run all commands from the **project root** unless noted.

| Script | Purpose |
|--------|--------|
| [bootstrap](bootstrap/README.md) | One-click clean build and deploy of the full stack |
| [chaos_test](chaos_test/README.md) | Generate traffic patterns to validate observability (4xx/5xx) |
| [unit_test](unit_test/README.md) | Run Go reliability test (chaos priority over cache) |

## Quick reference

```bash
# Deploy the stack (run from project root)
chmod +x scripts/bootstrap/bootstrap.sh
./scripts/bootstrap/bootstrap.sh

# After stack is up: chaos / observability test
./scripts/chaos_test/chaos_test.sh

# Run reliability unit test (requires Go)
./scripts/unit_test/unit_test.sh
```
