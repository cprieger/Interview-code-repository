# unit_test.sh

**Purpose:** Runs the Go reliability test that ensures chaos injection takes priority over cache-aside behavior. If the cache masked synthetic faults, the test would fail.

## What it does

- Runs a single test with verbose output:  
  `go test -v ./internal/weather/ -run TestGetWeather_ChaosPriority`
- **On success:** Prints “RELIABILITY CHECK PASSED” and confirms “Chaos Injection > Cache-Aside.”
- **On failure:** Prints “RELIABILITY CHECK FAILED” and exits with code 1 so CI can detect logic errors (e.g. cache masking synthetic faults).

The script changes into the project root automatically so `./internal/weather/` resolves correctly.

## Usage

Run from anywhere (script switches to repo root):

```bash
chmod +x scripts/unit_test/unit_test.sh
./scripts/unit_test/unit_test.sh
```

## Requirements

- Go toolchain
- No need for Docker; this is a local unit test.

## When to use

- Before committing changes to weather client/cache/chaos logic.
- In CI to enforce that chaos injection is not masked by caching.
