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

	mux.Handle("GET /metrics", promhttp.Handler())
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"up"}`))
	})

	mux.HandleFunc("GET /weather/{location}", func(w http.ResponseWriter, r *http.Request) {
		location := r.PathValue("location")

		// Inject Chaos Header into Context using the type-safe Key
		chaosHeader := r.Header.Get("X-Chaos-Mode")
		ctx := context.WithValue(r.Context(), weather.ChaosTriggerKey, chaosHeader)

		data, err := wClient.GetWeather(ctx, location)
		if err != nil {
			slog.Warn("Request failed (Chaos or Upstream)", "error", err, "location", location)
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
		ctx := context.WithValue(r.Context(), "trace_id", traceID)

		next.ServeHTTP(w, r.WithContext(ctx))

		obs.HttpRequestDuration.WithLabelValues(r.URL.Path).Observe(time.Since(start).Seconds())
		obs.HttpRequestsTotal.WithLabelValues("N/A", r.URL.Path).Inc()
		slog.Info("processed", "path", r.URL.Path, "trace_id", traceID, "latency", time.Since(start))
	})
}
