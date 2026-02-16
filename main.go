package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	"weather-service/internal/weather"

	"github.com/google/uuid"
)

func main() {
	// 1. Setup Structured Logging
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	wClient := weather.NewClient()

	// 2. Define the Core Business Logic
	// This handler doesn't know about chaos; it just fetches weather.
	apiHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Universal Path Parsing (Safe for all Go versions)
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(`{"status":"up"}`))
			return
		}

		if strings.HasPrefix(r.URL.Path, "/weather/") {
			location := strings.TrimPrefix(r.URL.Path, "/weather/")

			// Pass the Context (which might contain the Chaos trigger) to the client
			data, err := wClient.GetWeather(r.Context(), location)
			if err != nil {
				slog.Error("request failed", "error", err)
				w.WriteHeader(http.StatusInternalServerError)
				fmt.Fprint(w, err.Error())
				return
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(data)
			return
		}

		http.NotFound(w, r)
	})

	// 3. Wrap with SRE Middleware
	// The request goes: SRE Middleware -> API Handler
	finalHandler := sreMiddleware(apiHandler)

	slog.Info("Server starting on :8080 (Elegant Mode)")
	http.ListenAndServe(":8080", finalHandler)
}

// sreMiddleware handles Observability (Logs/Traces) and Fault Injection
func sreMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		traceID := uuid.New().String()

		// A. Detect Chaos Intent (Header OR Query)
		isChaos := "false"
		if r.Header.Get("X-Chaos-Mode") == "true" || r.URL.Query().Get("chaos") == "true" {
			isChaos = "true"
		}

		// B. Inject into Context
		ctx := context.WithValue(r.Context(), "trace_id", traceID)
		ctx = context.WithValue(ctx, "chaos_trigger", isChaos)

		// C. Log & Execute
		slog.Info("request started", "path", r.URL.Path, "chaos", isChaos, "trace_id", traceID)
		next.ServeHTTP(w, r.WithContext(ctx))
		slog.Info("request completed", "path", r.URL.Path, "latency", time.Since(start))
	})
}
