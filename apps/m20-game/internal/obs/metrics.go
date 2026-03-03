// Package obs registers all Prometheus metrics for m20-game.
// Metrics are auto-registered at package init via promauto — no manual registration needed.
package obs

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// HTTP layer — mirrors the weather-service pattern.
	HTTPRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "m20_http_requests_total",
		Help: "Total HTTP requests by path, method, and status code.",
	}, []string{"path", "method", "code", "status_text"})

	HTTPRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "m20_http_request_duration_seconds",
		Help:    "HTTP request latency in seconds.",
		Buckets: prometheus.DefBuckets,
	}, []string{"path", "method"})

	// Game signals.
	TilesGeneratedTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "m20_tiles_generated_total",
		Help: "Total tiles generated.",
	}, []string{"tile_type"})

	CombatRollsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "m20_combat_rolls_total",
		Help: "Total combat rolls by outcome.",
	}, []string{"outcome"}) // crit_success | success | failure | crit_failure

	MonstersDefeatedTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "m20_monsters_defeated_total",
		Help: "Total monsters defeated by type.",
	}, []string{"monster_name"})

	CharactersCreatedTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "m20_characters_created_total",
		Help: "Total characters created by class.",
	}, []string{"class"})

	GamesStartedTotal = promauto.NewCounter(prometheus.CounterOpts{
		Name: "m20_games_started_total",
		Help: "Total game sessions started.",
	})

	ActiveSessions = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "m20_active_sessions",
		Help: "Current number of active game sessions.",
	})

	// AI subsystem.
	AIRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "m20_ai_requests_total",
		Help: "Total Ollama AI requests by type and status.",
	}, []string{"type", "status"}) // type: riddle|dialogue  status: success|timeout|error

	AIRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "m20_ai_request_duration_seconds",
		Help:    "Ollama request latency in seconds.",
		Buckets: []float64{0.1, 0.5, 1, 2, 5, 10, 30},
	}, []string{"type"})
)
