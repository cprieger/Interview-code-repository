.PHONY: build run test clean help

# Default target
help:
	@echo "Weather Service Management Commands:"
	@echo "  make build    - Build the binary"
	@echo "  make run      - Run the service locally"
	@echo "  make test     - Run unit tests"
	@echo "  make clean    - Remove build artifacts"

build:
	go build -o bin/weather-api cmd/server/main.go

run: build
	WEATHER_API_KEY="your_actual_key_here" ./bin/weather-api

test:
	go test -v ./...

clean:
	rm -rf bin/