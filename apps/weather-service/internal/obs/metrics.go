package obs

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// We use promauto to automatically register these metrics.
// This package is the single source of truth for:
// - HTTP request metrics used by Prometheus alerting rules
// - Cache-related metrics that complement them.
var (
	// HTTP Request Counter (Rate, success vs failure, status codes)
	HttpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "weather_service_http_requests_total",
			Help: "Total number of HTTP requests by path, method, status code, and status text.",
		},
		[]string{"path", "method", "code", "status_text"},
	)

	// HTTP Latency Histogram (Duration)
	HttpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "weather_service_http_request_duration_seconds",
			Help:    "Duration of HTTP requests in seconds.",
			Buckets: prometheus.DefBuckets, // Standard SRE buckets (ms to seconds)
		},
		[]string{"path", "method"},
	)

	// Cache Metrics (Operational Excellence)
	CacheHits = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "weather_service_cache_hits_total",
			Help: "Total number of successful cache lookups.",
		},
	)

	CacheMisses = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "weather_service_cache_misses_total",
			Help: "Total number of cache misses requiring upstream fetch.",
		},
	)

	// Queue Metrics (KEDA-driven scaling visibility)
	QueueLength = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "weather_queue_length",
			Help: "Current number of jobs in the Redis queue (used by KEDA for scaling).",
		},
	)
	JobsProcessedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "weather_jobs_processed_total",
			Help: "Total jobs processed from the queue by outcome.",
		},
		[]string{"outcome"}, // "success" or "error"
	)
)