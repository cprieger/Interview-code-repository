# M20 Game — Makefile
# Usage: make <target>
#
# All targets match the weather-service patterns for consistency.

BINARY       := m20-game
BUILD_DIR    := bin
MAIN         := cmd/server/main.go
COVERAGE_OUT := coverage.out
COVERAGE_HTML:= coverage.html

.PHONY: build run test test-coverage test-html docker-up docker-down clean help

## build: Compile the Go binary to bin/m20-game
build:
	@mkdir -p $(BUILD_DIR)
	go build -o $(BUILD_DIR)/$(BINARY) $(MAIN)
	@echo "✓ Built $(BUILD_DIR)/$(BINARY)"

## run: Build and run locally (default port 8082)
run: build
	DB_PATH=./data/m20.db OLLAMA_URL=http://localhost:11434 ./$(BUILD_DIR)/$(BINARY)

## test: Run all tests with verbose output
test:
	go test -v ./...

## test-coverage: Run tests and generate coverage report
test-coverage:
	go test -v -coverprofile=$(COVERAGE_OUT) ./...
	@go tool cover -func=$(COVERAGE_OUT) | tail -1

## test-html: Open coverage report in browser
test-html: test-coverage
	go tool cover -html=$(COVERAGE_OUT) -o $(COVERAGE_HTML)
	@echo "✓ Coverage report: $(COVERAGE_HTML)"

## docker-up: Build image and bring up full stack (m20 + Ollama + Prometheus + Grafana)
docker-up:
	./scripts/bootstrap/bootstrap.sh

## docker-down: Tear down all services
docker-down:
	docker compose down

## clean: Remove build artifacts
clean:
	rm -rf $(BUILD_DIR) $(COVERAGE_OUT) $(COVERAGE_HTML) data/

## help: Print this help
help:
	@grep -E '^## ' Makefile | sed 's/## //'
