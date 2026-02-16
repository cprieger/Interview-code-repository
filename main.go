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

	//Moved Dashboard to microservice. Frontend should be seperated anyways.

	// --- 2. OTHER SYSTEM ROUTES ---
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"up"}`))
	})

	// --- 3. PARAMETERIZED WEATHER ROUTE ---
	// Registering this last ensures it doesn't "eat" the other routes.
	mux.HandleFunc("/weather/{location}", func(w http.ResponseWriter, r *http.Request) {
		location := r.PathValue("location")

		// Guardrail
		if location == "dashboard" || location == "metrics" || location == "health" {
			http.NotFound(w, r)
			return
		}

		ctx := r.Context()
		if r.Header.Get("X-Chaos-Mode") == "true" {
			ctx = context.WithValue(ctx, "chaos_trigger", "true")
		}

		data, err := wClient.GetWeather(ctx, location)
		if err != nil {
			http.Error(w, "internal service error", 500)
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
		slog.Info("server starting", "port", 8080)
		srv.ListenAndServe()
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

		next.ServeHTTP(w, r)

		obs.HttpRequestDuration.WithLabelValues(r.URL.Path).Observe(time.Since(start).Seconds())
		obs.HttpRequestsTotal.WithLabelValues("200", r.URL.Path).Inc()
		slog.Info("request", "path", r.URL.Path, "trace_id", traceID)
	})
}
