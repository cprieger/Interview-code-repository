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

	"weather-service/internal/obs"
	"weather-service/internal/weather"
)

// observabilityMiddleware handles Correlation IDs and ensures the context
// is correctly propagated down the chain.
func observabilityMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// 1. Generate or retrieve Trace ID
		traceID := r.Header.Get("X-Correlation-ID")
		if traceID == "" {
			traceID = uuid.New().String()
		}
		w.Header().Set("X-Correlation-ID", traceID)

		// 2. ENFORCE CONTEXT PROPAGATION: Use r.WithContext
		// This is critical for SRE traceability and Chaos testing.
		ctx := context.WithValue(r.Context(), "trace_id", traceID)
		r = r.WithContext(ctx)

		next.ServeHTTP(w, r)

		// 3. Record RED Metrics
		duration := time.Since(start)
		obs.HttpRequestDuration.WithLabelValues(r.URL.Path).Observe(duration.Seconds())
		obs.HttpRequestsTotal.WithLabelValues("N/A", r.URL.Path).Inc()

		slog.Info("request processed",
			slog.String("trace_id", traceID),
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.Duration("latency", duration),
		)
	})
}

func main() {
	// Initialize Structured JSON Logger with Debug level to verify Chaos triggers
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})).With(
		slog.String("service", "weather-service"),
	)
	slog.SetDefault(logger)

	wClient := weather.NewClient()
	mux := http.NewServeMux()

	// --- SYSTEM ROUTES ---
	mux.Handle("GET /metrics", promhttp.Handler())

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"up"}`))
	})

	// --- WEATHER API ENDPOINT ---
	mux.HandleFunc("GET /weather/{location}", func(w http.ResponseWriter, r *http.Request) {
		location := r.PathValue("location")
		traceID, _ := r.Context().Value("trace_id").(string)

		// 1. CAPTURE CHAOS HEADER
		chaosHeader := r.Header.Get("X-Chaos-Mode")

		// 2. INJECT INTO CONTEXT: Use the type-safe Key from the weather package
		ctx := context.WithValue(r.Context(), weather.ChaosTriggerKey, chaosHeader)

		if chaosHeader == "true" {
			slog.Warn("!!! CHAOS TRIGGER DETECTED AT HANDLER !!!", slog.String("trace_id", traceID))
		}

		// 3. CALL ENGINE WITH ENRICHED CONTEXT
		data, err := wClient.GetWeather(ctx, location)
		if err != nil {
			slog.Error("weather request failed",
				slog.Any("error", err),
				slog.String("trace_id", traceID),
				slog.String("location", location),
			)

			// Force a 500 status for Prometheus alerting
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprint(w, err.Error())
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(data)
	})

	// --- SERVER LIFECYCLE ---
	srv := &http.Server{
		Addr:         ":8080",
		Handler:      observabilityMiddleware(mux),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		slog.Info("Weather API starting", slog.Int("port", 8080))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server fatal error", slog.Any("error", err))
			os.Exit(1)
		}
	}()

	<-done
	slog.Warn("shutdown signal received")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("graceful shutdown failed", slog.Any("error", err))
	}
	slog.Info("server exited safely")
}
