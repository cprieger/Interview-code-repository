#!/bin/bash
set -e

echo "🔒 WRITING CORRECTED ARCHITECTURE TO DISK..."

# 1. OVERWRITE main.go (Removed unused "fmt" import)
cat <<EOF > cmd/server/main.go
package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/google/uuid"
	"weather-service/internal/weather"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	// STARTUP BANNER
	slog.Error("!!! BUILD: ELEGANT MIDDLEWARE MODE ACTIVE !!!")

	wClient := weather.NewClient()
	
	// BUSINESS LOGIC
	apiHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("{\"status\":\"up\"}"))
			return
		}

		if strings.HasPrefix(r.URL.Path, "/weather/") {
			location := strings.TrimPrefix(r.URL.Path, "/weather/")
			
			// Pass Context containing the chaos trigger
			data, err := wClient.GetWeather(r.Context(), location)
			if err != nil {
				slog.Error("API Handler: Returning 500", "error", err)
				http.Error(w, err.Error(), 500)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(data)
			return
		}

		http.NotFound(w, r)
	})

	// Wrap in SRE Middleware
	slog.Info("Server starting on :8080")
	http.ListenAndServe(":8080", sreMiddleware(apiHandler))
}

func sreMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		traceID := uuid.New().String()
		
		// DETECT CHAOS (Header OR Query)
		isChaos := "false"
		if r.Header.Get("X-Chaos-Mode") == "true" || r.URL.Query().Get("chaos") == "true" {
			isChaos = "true"
		}

		// INJECT INTO CONTEXT
		ctx := context.WithValue(r.Context(), "chaos_trigger", isChaos)
		ctx = context.WithValue(ctx, "trace_id", traceID)

		if isChaos == "true" {
			slog.Warn("SRE MIDDLEWARE: Chaos Detected", "trace_id", traceID)
		}

		next.ServeHTTP(w, r.WithContext(ctx))
		
		slog.Info("request completed", "path", r.URL.Path, "latency", time.Since(start))
	})
}
EOF

# 2. OVERWRITE client.go (Fault Logic)
cat <<EOF > internal/weather/client.go
package weather

import (
	"context"
	"fmt"
	"sync"
)

type WeatherData struct {
	Temperature float64 \`json:"temperature"\`
	Conditions  string  \`json:"conditions"\`
}

type Client struct {
	cache sync.Map
}

func NewClient() *Client {
	return &Client{}
}

func (c *Client) GetWeather(ctx context.Context, location string) (*WeatherData, error) {
	// CHECK CONTEXT FOR CHAOS
	if val, _ := ctx.Value("chaos_trigger").(string); val == "true" {
		return nil, fmt.Errorf("simulated_upstream_failure_500")
	}

	// Normal Cache Logic
	if val, ok := c.cache.Load(location); ok {
		data := val.(WeatherData)
		return &data, nil
	}

	data := WeatherData{Temperature: 72.0, Conditions: "Sunny"}
	c.cache.Store(location, data)
	return &data, nil
}
EOF

echo "🗑️  CLEANING: Removing old containers and images..."
docker-compose down --rmi all --volumes --remove-orphans

echo "🏗️  BUILDING: Forcing clean build..."
docker-compose build --no-cache weather-service

echo "🚀 DEPLOYING..."
docker-compose up -d

echo "⏳ WAITING FOR STARTUP..."
sleep 5

# Verify the banner
if docker-compose logs weather-service | grep -q "ELEGANT MIDDLEWARE MODE"; then
    echo "✅ SUCCESS: New code is active!"
else
    echo "❌ FAILURE: Still running old code."
    docker-compose logs weather-service
    exit 1
fi