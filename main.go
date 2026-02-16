package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	// 1. Setup Structured Logging with Service Context
	// slog.JSONHandler includes time by default, but we can customize it here
	opts := &slog.HandlerOptions{
		AddSource: true, // Optional: includes the file/line number in logs
	}

	// Initialize the handler with stdout
	handler := slog.NewJSONHandler(os.Stdout, opts)

	// Inject "service" and "env" globally so every log line has them
	logger := slog.New(handler).With(
		slog.String("service", "weather-alert-service"),
		slog.String("env", "production"), // Or pull from os.Getenv("ENV")
	)

	slog.SetDefault(logger)

	logger.Info("service initialized", "status", "ready")

	// 2. Initialize Router
	mux := http.NewServeMux()

	// Health Check (Requirement 2.0)
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"up"}`))
	})

	// 3. Configure Server
	srv := &http.Server{
		Addr:         ":8080",
		Handler:      mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// 4. Graceful Shutdown (Bonus Requirement)
	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		logger.Info("starting server", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("listen failed", "error", err)
			os.Exit(1)
		}
	}()

	// Simple Dashboard Endpoint
	mux.HandleFunc("GET /dashboard$", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		fmt.Fprint(w, `
			<html>
				<body style="font-family: sans-serif; padding: 20px; background: #f4f4f9;">
					<h1>Weather SRE Dashboard</h1>
					<div id="root">
						<h3>Service Metrics</h3>
						<iframe src="http://localhost:9090/graph" width="100%" height="400"></iframe>
						<h3>Active Alerts</h3>
						<iframe src="http://localhost:9090/alerts" width="100%" height="400"></iframe>
					</div>
				</body>
			</html>
		`)
	})

	<-done // Wait for CTRL+C or SIGTERM
	logger.Info("shutting down weather service")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("forced shutdown", "error", err)
	}
	logger.Info("server exited")
}
