package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"weather-service/internal/weather"

	"github.com/google/uuid"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	wClient := weather.NewClient()
	mux := http.NewServeMux()

	mux.HandleFunc("GET /weather/{location}", func(w http.ResponseWriter, r *http.Request) {
		location := r.PathValue("location")
		traceID := uuid.New().String()

		// Capture Header
		chaosHeader := r.Header.Get("X-Chaos-Mode")

		// Set Context
		ctx := context.WithValue(r.Context(), "trace_id", traceID)
		ctx = context.WithValue(ctx, weather.ChaosTriggerKey, chaosHeader)

		slog.Info("Handler received request", "path", r.URL.Path, "chaos_header", chaosHeader, "trace_id", traceID)

		data, err := wClient.GetWeather(ctx, location)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprint(w, err.Error())
			return
		}

		json.NewEncoder(w).Encode(data)
	})

	slog.Info("Server starting on :8080")
	http.ListenAndServe(":8080", mux)
}
