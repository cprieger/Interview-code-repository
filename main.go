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

func observabilityMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		traceID := r.Header.Get("X-Correlation-ID")
		if traceID == "" {
			traceID = uuid.New().String()
		}
		w.Header().Set("X-Correlation-ID", traceID)

		ctx := context.WithValue(r.Context(), "trace_id", traceID)
		next.ServeHTTP(w, r.WithContext(ctx))

		obs.HttpRequestDuration.WithLabelValues(r.URL.Path).Observe(time.Since(start).Seconds())
		obs.HttpRequestsTotal.WithLabelValues("N/A", r.URL.Path).Inc()
	})
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug}))
	slog.SetDefault(logger)

	wClient := weather.NewClient()
	mux := http.NewServeMux()

	mux.Handle("GET /metrics", promhttp.Handler())
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"up"}`))
	})

	mux.HandleFunc("GET /weather/{location}", func(w http.ResponseWriter, r *http.Request) {
		location := r.PathValue("location")

		// --- THE FIX: DIRECT INJECTION ---
		chaosHeader := r.Header.Get("X-Chaos-Mode")

		// We create a fresh context here to guarantee propagation to the client
		ctx := context.WithValue(r.Context(), weather.ChaosTriggerKey, chaosHeader)

		if chaosHeader == "true" {
			slog.Warn("!!! HANDLER LEVEL: Chaos Header Detected !!!", "location", location)
		}

		data, err := wClient.GetWeather(ctx, location)
		if err != nil {
			slog.Error("Intercepted Error", "error", err)
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprint(w, err.Error())
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
		slog.Info("API Live", "port", 8080)
		srv.ListenAndServe()
	}()
	<-stop
	srv.Shutdown(context.Background())
}
