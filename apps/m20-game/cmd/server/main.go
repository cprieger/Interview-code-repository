// Package main is the HTTP entrypoint for m20-game.
// It wires routes, SRE middleware, Prometheus metrics, and all game handlers.
// Static files are served from web/static/ — no separate file server needed.
package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"m20-game/internal/ai"
	"m20-game/internal/character"
	"m20-game/internal/config"
	"m20-game/internal/game"
	"m20-game/internal/obs"
	"m20-game/internal/resources"
)

type contextKey string

const traceIDKey contextKey = "trace_id"

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	cfg := config.Load()
	slog.Info("m20-game starting", "port", cfg.Port, "db", cfg.DBPath, "ollama", cfg.OllamaURL)

	// Ensure DB directory exists
	if err := os.MkdirAll(filepath.Dir(cfg.DBPath), 0755); err != nil {
		slog.Error("failed to create DB directory", "error", err)
		os.Exit(1)
	}

	store, err := character.NewStore(cfg.DBPath)
	if err != nil {
		slog.Error("failed to open character store", "error", err)
		os.Exit(1)
	}
	defer store.Close()

	aiClient := ai.NewClient(cfg.OllamaURL)

	mux := http.NewServeMux()

	// Prometheus metrics — bypass SRE middleware
	mux.Handle("/metrics", promhttp.Handler())

	// All game routes run through SRE middleware
	api := buildAPIHandler(store, aiClient)
	mux.Handle("/", sreMiddleware(api))

	addr := ":" + cfg.Port
	slog.Info("server ready", "addr", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}

// buildAPIHandler wires all routes and returns the main handler.
func buildAPIHandler(store *character.Store, aiClient *ai.Client) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path
		method := r.Method

		switch {
		// ── Health ──────────────────────────────────────────────────────────
		case path == "/health" && method == http.MethodGet:
			writeJSON(w, http.StatusOK, map[string]string{"status": "up"})

		// ── Tile generation ─────────────────────────────────────────────────
		case path == "/api/tile" && method == http.MethodGet:
			handleTile(w, r)

		// ── Map / land generation ────────────────────────────────────────────
		case path == "/api/land" && method == http.MethodPost:
			handleLand(w, r)

		// ── Scavenging ───────────────────────────────────────────────────────
		case path == "/api/scavenge" && method == http.MethodGet:
			handleScavenge(w, r)

		// ── Items / crafting ─────────────────────────────────────────────────
		case path == "/api/items" && method == http.MethodGet:
			handleItems(w, r)

		case path == "/api/craft" && method == http.MethodPost:
			handleCraft(w, r)

		// ── Combat ───────────────────────────────────────────────────────────
		case path == "/api/combat/roll" && method == http.MethodPost:
			handleCombatRoll(w, r)

		// ── AI / Sphinx ───────────────────────────────────────────────────────
		case path == "/api/ai/riddle" && method == http.MethodGet:
			handleRiddle(w, r, aiClient)

		// ── Character ────────────────────────────────────────────────────────
		case path == "/api/character" && method == http.MethodPost:
			handleCreateCharacter(w, r, store)

		case strings.HasPrefix(path, "/api/character/"):
			handleCharacterByID(w, r, path, store)

		// ── Admin page ───────────────────────────────────────────────────────
		case path == "/admin" && method == http.MethodGet:
			http.ServeFile(w, r, "web/static/admin.html")

		// ── Static files & game UI ────────────────────────────────────────────
		case path == "/" || path == "/index.html":
			obs.GamesStartedTotal.Inc()
			http.ServeFile(w, r, "web/static/index.html")

		case strings.HasPrefix(path, "/js/") || strings.HasPrefix(path, "/css/"):
			http.ServeFile(w, r, "web/static"+path)

		default:
			writeError(w, http.StatusNotFound, "NOT_FOUND", "route not found", "check the path and method")
		}
	})
}

// ── Handlers ──────────────────────────────────────────────────────────────────

func handleTile(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	if id == "" {
		id = uuid.New().String()[:8]
	}
	writeJSON(w, http.StatusOK, game.GenerateTile(id))
}

func handleLand(w http.ResponseWriter, r *http.Request) {
	var req struct {
		TileCount int `json:"tileCount"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.TileCount == 0 {
		req.TileCount = 9 // 3x3 default map
	}
	writeJSON(w, http.StatusOK, game.GenerateLand(req.TileCount))
}

func handleScavenge(w http.ResponseWriter, r *http.Request) {
	level, _ := strconv.Atoi(r.URL.Query().Get("level"))
	if level < 1 {
		level = 3 // default scouting level
	}
	writeJSON(w, http.StatusOK, game.Scavenge(level))
}

func handleItems(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"supplies":  resources.Supplies(),
		"craftable": resources.CraftableItems(),
		"classes":   resources.Classes(),
	})
}

func handleCraft(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Materials    []string `json:"materials"`
		CraftingLevel int    `json:"crafting_level"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "invalid JSON body", "send {materials: [...], crafting_level: N}")
		return
	}
	if len(req.Materials) == 0 {
		writeError(w, http.StatusBadRequest, "NO_MATERIALS", "no materials provided", "include at least one material name")
		return
	}
	craftable := resources.CanCraft(req.Materials, req.CraftingLevel)
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"craftable": craftable,
		"count":     len(craftable),
	})
}

func handleCombatRoll(w http.ResponseWriter, r *http.Request) {
	var req game.CombatRollRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "invalid JSON body", "send {stat: N, bonus: N}")
		return
	}
	critThreshold := 20
	if ct, _ := strconv.Atoi(r.URL.Query().Get("crit_threshold")); ct > 0 {
		critThreshold = ct
	}
	writeJSON(w, http.StatusOK, game.Roll(req, critThreshold))
}

func handleRiddle(w http.ResponseWriter, r *http.Request, aiClient *ai.Client) {
	ctx, cancel := context.WithTimeout(r.Context(), 25*time.Second)
	defer cancel()
	result := aiClient.GenerateRiddle(ctx)
	writeJSON(w, http.StatusOK, result)
}

func handleCreateCharacter(w http.ResponseWriter, r *http.Request, store *character.Store) {
	var req character.GenerateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "invalid JSON body", "send {name: \"...\", class: \"...\"}")
		return
	}
	c, err := character.Generate(req)
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_CHARACTER", err.Error(), "check name and class fields")
		return
	}
	if err := store.Save(r.Context(), c); err != nil {
		slog.Error("save character failed", "error", err)
		writeError(w, http.StatusInternalServerError, "STORE_ERROR", "failed to save character", "check server logs")
		return
	}
	writeJSON(w, http.StatusCreated, c)
}

func handleCharacterByID(w http.ResponseWriter, r *http.Request, path string, store *character.Store) {
	// /api/character/:id  or  /api/character/:id/sheet
	trimmed := strings.TrimPrefix(path, "/api/character/")
	parts := strings.SplitN(trimmed, "/", 2)
	id := parts[0]

	if id == "" {
		writeError(w, http.StatusBadRequest, "MISSING_ID", "character ID required", "use /api/character/:id")
		return
	}

	c, err := store.Load(r.Context(), id)
	if err != nil {
		slog.Error("load character failed", "id", id, "error", err)
		writeError(w, http.StatusInternalServerError, "STORE_ERROR", "failed to load character", "check server logs")
		return
	}
	if c == nil {
		writeError(w, http.StatusNotFound, "CHARACTER_NOT_FOUND", "no character with that ID", "check character_id")
		return
	}

	// /api/character/:id/sheet — full sheet with class details
	if len(parts) == 2 && parts[1] == "sheet" {
		classDef := resources.ClassByName(c.Class)
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"character":  c,
			"class_def":  classDef,
			"xp_to_next": character.XPForNextLevel(c.Level),
			"ready_to_level_up": c.IsReadyToLevelUp(),
			"max_inventory": c.MaxInventorySlots(),
		})
		return
	}

	writeJSON(w, http.StatusOK, c)
}

// ── SRE Middleware ────────────────────────────────────────────────────────────

func sreMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		traceID := uuid.New().String()
		ctx := context.WithValue(r.Context(), traceIDKey, traceID)

		rw := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(rw, r.WithContext(ctx))

		duration := time.Since(start).Seconds()

		// Normalize path labels to avoid high-cardinality explosions
		metricPath := normalizePath(r.URL.Path)

		obs.HTTPRequestsTotal.WithLabelValues(
			metricPath, r.Method,
			strconv.Itoa(rw.statusCode),
			http.StatusText(rw.statusCode),
		).Inc()
		obs.HTTPRequestDuration.WithLabelValues(metricPath, r.Method).Observe(duration)

		slog.Info("request",
			"path", r.URL.Path,
			"method", r.Method,
			"status", rw.statusCode,
			"latency_ms", duration*1000,
			"trace_id", traceID,
		)
	})
}

func normalizePath(path string) string {
	switch {
	case strings.HasPrefix(path, "/api/character/"):
		return "/api/character/:id"
	case strings.HasPrefix(path, "/js/"):
		return "/js/*"
	case strings.HasPrefix(path, "/css/"):
		return "/css/*"
	default:
		return path
	}
}

type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.statusCode = code
	r.ResponseWriter.WriteHeader(code)
}

// ── Response helpers ─────────────────────────────────────────────────────────

func writeJSON(w http.ResponseWriter, code int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("encode response failed", "error", err)
	}
}

// writeError returns a structured error response.
// Format: {"error": {"code": "...", "message": "...", "hint": "..."}}
func writeError(w http.ResponseWriter, httpCode int, code, message, hint string) {
	writeJSON(w, httpCode, map[string]interface{}{
		"error": map[string]string{
			"code":    code,
			"message": message,
			"hint":    hint,
		},
	})
}
