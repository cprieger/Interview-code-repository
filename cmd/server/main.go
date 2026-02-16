package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"weather-service/internal/obs"
	"weather-service/internal/weather"
)

// statusWriter captures the HTTP status code for Prometheus metrics and logging
type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

// observabilityMiddleware handles Correlation IDs, Detailed Logging, and RED metrics
func observabilityMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// 1. Generate/Capture Correlation ID 
		traceID := r.Header.Get("X-Correlation-ID")
		if traceID == "" {
			traceID = uuid.New().String()
		}
		w.Header().Set("X-Correlation-ID", traceID)

		// 2. Setup Context with Trace ID for downstream propagation [cite: 47]
		ctx := context.WithValue(r.Context(), "trace_id", traceID)
		
		// 3. Log Request Entry (Contextually Significant)
		slog.Info("request started",
			slog.String("trace_id", traceID),
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.String("remote_addr", r.RemoteAddr),
		)

		ww := &statusWriter{ResponseWriter: w, status: http.StatusOK}

		// 4. Execute Request
		next.ServeHTTP(ww, r.WithContext(ctx))

		// 5. Calculate Metrics and Log Request Exit [cite: 34]
		duration := time.Since(start)
		obs.HttpRequestDuration.WithLabelValues(r.URL.Path).Observe(duration.Seconds())
		obs.HttpRequestsTotal.WithLabelValues(http.StatusText(ww.status), r.URL.Path).Inc()

		slog.Info("request completed",
			slog.String("trace_id", traceID),
			slog.Int("status", ww.status),
			slog.Duration("latency", duration),
			slog.String("path", r.URL.Path),
		)
	})
}

func main() {
	// Initialize Structured JSON Logger 
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil)).With(
		slog.String("service", "weather-service"),
	)
	slog.SetDefault(logger)

	wClient := weather.NewClient()
	mux := http.NewServeMux()

	// Register Routes [cite: 22, 27, 29]
	mux.Handle("GET /metrics", promhttp.Handler())
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"up"}`))
	})
	
	mux.HandleFunc("GET /weather/{location}", func(w http.ResponseWriter, r *http.Request) {
		location := r.PathValue("location")
		
		// Fetch weather with context-aware client [cite: 45, 47]
		data, err := wClient.GetWeather(r.Context(), location)
		if err != nil {
			slog.Error("weather fetch failed", 
				"error", err, 
				"location", location,
				"trace_id", r.Context().Value("trace_id"),
			)
			http.Error(w, "failed to fetch weather data", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(data)
	})

	// Server Config with Timeout Management [cite: 47]
	srv := &http.Server{
		Addr:         ":8080",
		Handler:      observabilityMiddleware(mux),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	// Graceful Shutdown Implementation [cite: 60]
	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		slog.Info("service listening", "port", 8080)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			os.Exit(1)
		}
	}()

	<-done
	slog.Info("shutting down server")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
}