package main

import (
	"net/http"
	"time"
	"weather-service/internal/obs" // Import your new metrics package
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/google/uuid" // Run 'go get github.com/google/uuid'
)

// Simple middleware to track metrics and inject Correlation IDs
func metricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Requirement: Correlation IDs (Minimal tracing)
		traceID := uuid.New().String()
		w.Header().Set("X-Correlation-ID", traceID)

		// Create a custom response writer to capture status code
		ww := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		
		next.ServeHTTP(ww, r)

		// Record RED Metrics
		duration := time.Since(start).Seconds()
		obs.HttpRequestDuration.WithLabelValues(r.URL.Path).Observe(duration)
		obs.HttpRequestsTotal.WithLabelValues(string(rune(ww.status)), r.URL.Path).Inc()
	})
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

// ... rest of your main.go ...
// Inside main(), when setting up the router:
mux.Handle("GET /metrics", promhttp.Handler()) // Requirement: GET /metrics