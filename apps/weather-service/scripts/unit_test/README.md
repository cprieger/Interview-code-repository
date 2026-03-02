# unit_test.sh

**Purpose:** Runs the complete Go test suite with coverage reporting. Tests include unit tests for the weather client, HTTP handlers, SRE middleware, and integration tests.

## What it does

- Runs all tests across all packages with verbose output:  
  `go test -v -coverprofile=coverage.out ./...`
- Generates a coverage profile file (`coverage.out`) for detailed analysis.
- **On success:** Prints "ALL TESTS PASSED" and shows a coverage summary.
- **On failure:** Prints "TESTS FAILED" and exits with code 1 for CI detection.

The script changes into the project root automatically so all package paths resolve correctly.

## Test Coverage

The suite includes:
- **Weather Client Tests** (`internal/weather/`): Cache hits/misses, chaos priority, edge cases
- **HTTP Handler Tests** (`cmd/server/handler_test.go`): Health endpoint, weather endpoint, 404s, chaos handling
- **SRE Middleware Tests** (`cmd/server/middleware_test.go`): Chaos detection (query param + header), context propagation, metrics recording, path normalization, status code capture
- **Integration Tests** (`cmd/server/integration_test.go`): Full request flow, chaos injection end-to-end, health checks

## Usage

Run from anywhere (script switches to repo root):

```bash
chmod +x scripts/unit_test/unit_test.sh
./scripts/unit_test/unit_test.sh
```

## Requirements

- Go toolchain
- No need for Docker; these are local unit/integration tests.

## When to use

- Before committing any code changes
- In CI/CD pipelines to ensure all functionality works
- To verify test coverage meets your standards
- After refactoring to ensure nothing broke

## Coverage Analysis

After running, view detailed HTML coverage report:
```bash
go tool cover -html=coverage.out
```
