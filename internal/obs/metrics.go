package obs

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// We use promauto to automatically register these metrics
var (
	// Request Counter (Rate & Errors)
	HttpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "weather_service_http_requests_total",
			Help: "Total number of HTTP requests by status code and path.",
		},
		[]string{"code", "path"},
	)

	// Latency Histogram (Duration)
	HttpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "weather_service_http_request_duration_seconds",
			Help:    "Duration of HTTP requests in seconds.",
			Buckets: prometheus.DefBuckets, // Standard SRE buckets (ms to seconds)
		},
		[]string{"path"},
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
)