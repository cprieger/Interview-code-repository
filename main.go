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

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil)).With(slog.String("service", "weather-service"))
	slog.SetDefault(logger)

	wClient := weather.NewClient()
	mux := http.NewServeMux()

	// 1. Static System Routes (Exact Match)
	mux.Handle("GET /metrics", promhttp.Handler())
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"up"}`))
	})

	// 2. Headless Weather API
	mux.HandleFunc("GET /weather/{location}", func(w http.ResponseWriter, r *http.Request) {
		location := r.PathValue("location")
		traceID := r.Context().Value("trace_id")

		// Detect and Inject Chaos
		chaosHeader := r.Header.Get("X-Chaos-Mode")
		ctx := context.WithValue(r.Context(), weather.ChaosTriggerKey, chaosHeader)

		if chaosHeader == "true" {
			slog.Info("Chaos header detected at edge", "trace_id", traceID)
		}

		data, err := wClient.GetWeather(ctx, location)
		if err != nil {
			slog.Error("Request failed", "error", err, "trace_id", traceID)
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(data)
	})

	srv := &http.Server{
		Addr:    ":8080",
		Handler: observabilityMiddleware(mux),
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		slog.Info("SRE Weather API Starting", "port", 8080)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			os.Exit(1)
		}
	}()

	<-stop
	ctx, _ := context.WithTimeout(context.Background(), 5*time.Second)
	srv.Shutdown(ctx)
}

func observabilityMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		traceID := uuid.New().String()
		w.Header().Set("X-Correlation-ID", traceID)

		// Inject traceID for downstream log correlation
		ctx := context.WithValue(r.Context(), "trace_id", traceID)

		next.ServeHTTP(w, r.WithContext(ctx))

		obs.HttpRequestDuration.WithLabelValues(r.URL.Path).Observe(time.Since(start).Seconds())
		obs.HttpRequestsTotal.WithLabelValues("N/A", r.URL.Path).Inc()
		slog.Info("processed", "path", r.URL.Path, "latency", time.Since(start), "trace_id", traceID)
	})
}
