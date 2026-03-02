# scripts/unit_test/

`unit_test.sh` — Run the full test suite via Docker (no Go required on host).

```bash
./scripts/unit_test/unit_test.sh
```

Runs `go test -v -coverprofile=coverage.out ./...` inside `golang:1.23-alpine`.
Prints per-package results and overall coverage summary.
