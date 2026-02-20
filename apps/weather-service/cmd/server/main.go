package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"weather-service/internal/obs"
	"weather-service/internal/queue"
	"weather-service/internal/weather"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type contextKey string

const traceIDContextKey contextKey = "trace_id"

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	slog.Info("!!! BUILD: METRICS + REDIS QUEUE ENABLED !!!")

	wClient := weather.NewClient()
	qClient := queue.NewClient()
	defer func() {
		if err := qClient.Close(); err != nil {
			slog.Error("redis client close failed", "error", err)
		}
	}()

	// Start Redis queue worker (consumes jobs, drives KEDA scaling visibility)
	go runQueueWorker(context.Background(), qClient, wClient)

	// Periodically update queue length metric for Prometheus/Grafana
	go runQueueLengthUpdater(context.Background(), qClient)

	// BUSINESS LOGIC
	apiHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			if _, err := w.Write([]byte("{\"status\":\"up\"}")); err != nil {
				slog.Error("health response write failed", "error", err)
			}
			return
		}

		// Queue load endpoint: POST /queue/load?count=N&chaos=true|false - bulk-load jobs for chaos/KEDA
		if r.URL.Path == "/queue/load" && r.Method == http.MethodPost {
			handleQueueLoad(w, r, qClient)
			return
		}

		// Queue stats: GET /queue/stats - current length for dashboards
		if r.URL.Path == "/queue/stats" && r.Method == http.MethodGet {
			handleQueueStats(w, r, qClient)
			return
		}

		if strings.HasPrefix(r.URL.Path, "/weather/") {
			location := strings.TrimPrefix(r.URL.Path, "/weather/")
			data, err := wClient.GetWeather(r.Context(), location)
			if err != nil {
				slog.Error("API Handler: Returning 500", "error", err)
				http.Error(w, err.Error(), 500)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			if err := json.NewEncoder(w).Encode(data); err != nil {
				slog.Error("weather response encode failed", "error", err)
				http.Error(w, "failed to encode response", http.StatusInternalServerError)
			}
			return
		}

		http.NotFound(w, r)
	})

	// METRICS & SRE MIDDLEWARE
	sreHandler := sreMiddleware(apiHandler)

	rootMux := http.NewServeMux()
	rootMux.Handle("/metrics", promhttp.Handler())
	rootMux.Handle("/", sreHandler)

	slog.Info("Server starting on :8080")
	if err := http.ListenAndServe(":8080", rootMux); err != nil {
		slog.Error("server failed", "error", err)
	}
}

func runQueueWorker(ctx context.Context, q *queue.Client, w *weather.Client) {
	for {
		select {
		case <-ctx.Done():
			return
		default:
			job, err := q.Pop(ctx)
			if err != nil {
				slog.Error("queue worker: pop failed", "error", err)
				time.Sleep(2 * time.Second)
				continue
			}
			if job == nil {
				continue
			}

			// Build context with chaos flag for weather client
			jCtx := weather.WithChaosTrigger(ctx, "false")
			if job.Chaos {
				jCtx = weather.WithChaosTrigger(ctx, "true")
			}

			_, err = w.GetWeather(jCtx, job.Location)
			if err != nil {
				obs.JobsProcessedTotal.WithLabelValues("error").Inc()
				slog.Warn("queue worker: job failed", "location", job.Location, "chaos", job.Chaos, "error", err)
			} else {
				obs.JobsProcessedTotal.WithLabelValues("success").Inc()
			}
		}
	}
}

func runQueueLengthUpdater(ctx context.Context, q *queue.Client) {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			n, err := q.Len(ctx)
			if err != nil {
				obs.QueueLength.Set(-1) // signal error
				continue
			}
			obs.QueueLength.Set(float64(n))
		}
	}
}

func handleQueueLoad(w http.ResponseWriter, r *http.Request, q *queue.Client) {
	countStr := r.URL.Query().Get("count")
	if countStr == "" {
		countStr = "100"
	}
	count, _ := strconv.Atoi(countStr)
	if count <= 0 || count > 10000 {
		count = 100
	}
	chaos := r.URL.Query().Get("chaos") == "true"

	jobs := make([]*queue.Job, count)
	for i := 0; i < count; i++ {
		jobs[i] = &queue.Job{Location: "lubbock", Chaos: chaos}
	}

	n, err := q.PushMany(r.Context(), jobs)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]interface{}{
		"loaded": n,
		"chaos":  chaos,
		"queue":  "weather:jobs",
	}); err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
	}
}

func handleQueueStats(w http.ResponseWriter, r *http.Request, q *queue.Client) {
	n, err := q.Len(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]interface{}{
		"length": n,
		"queue":  "weather:jobs",
	}); err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
	}
}

func sreMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		traceID := uuid.New().String()

		// DETECT CHAOS
		isChaos := "false"
		if r.Header.Get("X-Chaos-Mode") == "true" || r.URL.Query().Get("chaos") == "true" {
			isChaos = "true"
		}

		ctx := weather.WithChaosTrigger(r.Context(), isChaos)
		ctx = context.WithValue(ctx, traceIDContextKey, traceID)

		// WRAPPER FOR CAPTURING STATUS CODE
		rw := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(rw, r.WithContext(ctx))

		duration := time.Since(start).Seconds()

		// RECORD METRICS
		path := r.URL.Path
		if strings.HasPrefix(path, "/weather/") {
			path = "/weather/:location"
		} else if strings.HasPrefix(path, "/queue/") {
			path = "/queue/:action"
		}

		obs.HttpRequestsTotal.WithLabelValues(path, r.Method, strconv.Itoa(rw.statusCode), http.StatusText(rw.statusCode)).Inc()
		obs.HttpRequestDuration.WithLabelValues(path, r.Method).Observe(duration)

		slog.Info("request completed", "path", r.URL.Path, "status", rw.statusCode, "latency", duration, "status_text", http.StatusText(rw.statusCode))
	})
}

// statusRecorder captures the status code for metrics
type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (rec *statusRecorder) WriteHeader(code int) {
	rec.statusCode = code
	rec.ResponseWriter.WriteHeader(code)
}
