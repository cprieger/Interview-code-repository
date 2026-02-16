package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"weather-service/internal/config"
	"weather-service/internal/obs"
	"weather-service/internal/weather"
)

// statusWriter captures the HTTP status code for Prometheus metrics
type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

// metricsMiddleware handles RED metrics and Correlation ID injection
func metricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Requirement: Correlation IDs for request tracing [cite: 38]
		traceID := r.Header.Get("X-Correlation-ID")
		if traceID == "" {
			traceID = uuid.New().String()
		}
		w.Header().Set("X-Correlation-ID", traceID)

		// Wrap response writer to capture status
		ww := &statusWriter{ResponseWriter: w, status: http.StatusOK}

		// Add trace_id to request context for logging downstream
		ctx := context.WithValue(r.Context(), "trace_id", traceID)
		next.ServeHTTP(ww, r.WithContext(ctx))

		// Record RED Metrics 
		duration := time.Since(start).Seconds()
		obs.HttpRequestDuration.WithLabelValues(r.URL.Path).Observe(duration)
		obs.HttpRequestsTotal.WithLabelValues(fmt.Sprintf("%d", ww.status), r.URL.Path).Inc()
	})
}

func main() {
	// 1. Load Configuration [cite: 50]
	cfg := config.Load()

	// 2. Setup Structured Logging with Service Context [cite: 37]
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil)).With(
		slog.String("service", "weather-service"),
		slog.String("env", "local"),
	)
	slog.SetDefault(logger)

	// 3. Initialize Weather Client (The Engine)
	wClient := weather.NewClient(cfg.WeatherAPIKey)

	// 4. Initialize Router
	mux := http.NewServeMux()

	// Health Check [cite: 27, 28]
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
	})

	// Metrics Endpoint [cite: 29, 30]
	mux.Handle("GET /metrics", promhttp.Handler())

	// Weather Endpoint [cite: 21, 22]
	mux.HandleFunc("GET /weather/{location}", func(w http.ResponseWriter, r *http.Request) {
		location := r.PathValue("location")
		if location == "" {
			http.Error(w, "location is required", http.StatusBadRequest)
			return
		}

		// Use request context to ensure timeouts are respected 
		data, err := wClient.GetWeather(r.Context(), location)
		if err != nil {
			slog.Error("weather fetch failed", "error", err, "location", location)
			http.Error(w, "failed to fetch weather data", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(data)
	})

	// 5. Configure Server with SRE Best Practices 
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      metricsMiddleware(mux),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// 6. Graceful Shutdown Implementation [cite: 60]
	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		slog.Info("starting weather service", "port", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server failed to start", "error", err)
			os.Exit(1)
		}
	}()

	// Wait for termination signal
	<-done
	slog.Info("shutting down gracefully...")

	// Create a deadline for shutdown
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("graceful shutdown failed", "error", err)
		os.Exit(1)
	}

	slog.Info("server exited cleanly")
}