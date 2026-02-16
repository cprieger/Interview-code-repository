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
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"weather-service/internal/weather"
)

// --- METRICS ---
var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "weather_service_http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"path", "method", "code"},
	)

	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "weather_service_http_request_duration_seconds",
			Help:    "Duration of HTTP requests in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"path", "method"},
	)
)

func init() {
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
}

func main() {
	// 1. Setup Logger
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)
	slog.Info("!!! SERVER STARTING: METRICS & CHAOS ENABLED !!!")

	wClient := weather.NewClient()
	
	// 2. Business Logic
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

	// 3. SRE Middleware (The "Glue")
	sreHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		traceID := uuid.New().String()
		
		// Chaos Trigger
		isChaos := "false"
		if r.Header.Get("X-Chaos-Mode") == "true" || r.URL.Query().Get("chaos") == "true" {
			isChaos = "true"
		}

		// Context Injection
		ctx := context.WithValue(r.Context(), "chaos_trigger", isChaos)
		ctx = context.WithValue(ctx, "trace_id", traceID)

		// Status Recorder
		rw := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}
		apiHandler.ServeHTTP(rw, r.WithContext(ctx))
		
		// Metrics
		duration := time.Since(start).Seconds()
		path := "/weather/:location" // Simplified for cardinality
		if r.URL.Path == "/health" { path = "/health" }
		
		httpRequestsTotal.WithLabelValues(path, r.Method, http.StatusText(rw.statusCode)).Inc()
		httpRequestDuration.WithLabelValues(path, r.Method).Observe(duration)

		slog.Info("request completed", "path", r.URL.Path, "status", rw.statusCode)
	})

	// 4. Routing
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler()) // Metrics Endpoint
	mux.Handle("/", sreHandler)                // Application Logic

	http.ListenAndServe(":8080", mux)
}

type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (rec *statusRecorder) WriteHeader(code int) {
	rec.statusCode = code
	rec.ResponseWriter.WriteHeader(code)
}
