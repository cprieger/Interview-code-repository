.PHONY: build run test test-coverage test-html clean help

# Default target
help:
	@echo "Weather Service Management Commands:"
	@echo "  make build         - Build the binary"
	@echo "  make run           - Run the service locally"
	@echo "  make test          - Run all tests"
	@echo "  make test-coverage - Run tests with coverage report"
	@echo "  make test-html     - Generate HTML coverage report"
	@echo "  make clean         - Remove build artifacts and coverage files"

build:
	go build -o bin/weather-api cmd/server/main.go

run: build
	WEATHER_API_KEY="your_actual_key_here" ./bin/weather-api

test:
	go test -v ./...

test-coverage:
	go test -v -coverprofile=coverage.out ./...
	@echo ""
	@echo "📊 Coverage Summary:"
	@go tool cover -func=coverage.out | tail -1

test-html: test-coverage
	go tool cover -html=coverage.out -o coverage.html
	@echo "📄 HTML coverage report generated: coverage.html"

clean:
	rm -rf bin/
	rm -f coverage.out coverage.html