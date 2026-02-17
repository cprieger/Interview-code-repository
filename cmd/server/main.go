package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"weather-service/internal/obs"
	"weather-service/internal/weather"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	slog.Info("!!! BUILD: METRICS ENABLED !!!")

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

	// METRICS & SRE MIDDLEWARE
	// 1. We wrap the API with SRE logic (logging/chaos)
	sreHandler := sreMiddleware(apiHandler)

	// 2. We use a dedicated ServeMux to route /metrics separately
	rootMux := http.NewServeMux()

	// EXPOSE THE METRICS ENDPOINT
	rootMux.Handle("/metrics", promhttp.Handler())

	// Everything else goes to the app
	rootMux.Handle("/", sreHandler)

	slog.Info("Server starting on :8080")
	http.ListenAndServe(":8080", rootMux)
}

func sreMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		traceID := uuid.New().String()

		// DETECT CHAOS
		isChaos := "false"
		if r.Header.Get("X-Chaos-Mode") == "true" || r.URL.Query().Get("chaos") == "true" {
			isChaos = "true"
		}

		ctx := context.WithValue(r.Context(), "chaos_trigger", isChaos)
		ctx = context.WithValue(ctx, "trace_id", traceID)

		// WRAPPER FOR CAPTURING STATUS CODE
		rw := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(rw, r.WithContext(ctx))

		duration := time.Since(start).Seconds()

		// RECORD METRICS
		path := r.URL.Path
		// Low-cardinality path grouping (prevents memory explosion on random URLs)
		if strings.HasPrefix(path, "/weather/") {
			path = "/weather/:location"
		}

		obs.HttpRequestsTotal.WithLabelValues(path, r.Method, strconv.Itoa(rw.statusCode), http.StatusText(rw.statusCode)).Inc()
		obs.HttpRequestDuration.WithLabelValues(path, r.Method).Observe(duration)

		slog.Info("request completed", "path", r.URL.Path, "status", rw.statusCode, "latency", duration, "status_text", http.StatusText(rw.statusCode))
	})
}

// statusRecorder captures the status code for metrics
type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (rec *statusRecorder) WriteHeader(code int) {
	rec.statusCode = code
	rec.ResponseWriter.WriteHeader(code)
}
