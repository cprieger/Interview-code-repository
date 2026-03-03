// Package main is the HTTP entrypoint for m20-game.
// It wires routes, SRE middleware, Prometheus metrics, and all game handlers.
// Static files are served from web/static/ — no separate file server needed.
package main

import (
	"context"
	"encoding/json"
	"fmt"
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

		case path == "/api/combat/encounter" && method == http.MethodPost:
			handleCombatEncounter(w, r, aiClient)

		// ── Building entry ────────────────────────────────────────────────────
		case path == "/api/building/enter" && method == http.MethodPost:
			handleBuildingEnter(w, r, aiClient)

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
		"supplies":       resources.Supplies(),
		"craftable":      resources.CraftableItems(),
		"classes":        resources.Classes(),
		"equip_bonuses":  resources.EquipBonuses,
		"special_groups": resources.SpecialGroups,
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

// handleBuildingEnter enters a building and returns its monster group + Ollama flavor text.
// POST /api/building/enter  {"building": "Hospital", "character_class": "Brawler"}
func handleBuildingEnter(w http.ResponseWriter, r *http.Request, aiClient *ai.Client) {
	var req struct {
		Building       string `json:"building"`
		CharacterClass string `json:"character_class"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "invalid JSON body", "send {building: \"...\", character_class: \"...\"}")
		return
	}

	instance := game.GenerateSingleBuilding(req.Building)

	// Ask Ollama to set the scene — 10s timeout, fallback if unavailable.
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	flavorText := aiClient.BuildingEntrance(ctx, instance.Building.Name, instance.MonsterGroup.Name)

	// Get the leader monster's opening line.
	var leaderDialogue string
	if len(instance.MonsterGroup.Monsters) > 0 {
		leader := instance.MonsterGroup.Monsters[len(instance.MonsterGroup.Monsters)-1]
		ctx2, cancel2 := context.WithTimeout(r.Context(), 10*time.Second)
		defer cancel2()
		leaderDialogue = aiClient.MonsterDialogue(ctx2, leader.Name)
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"building":        instance.Building,
		"monster_group":   instance.MonsterGroup,
		"flavor_text":     flavorText,
		"leader_dialogue": leaderDialogue,
	})
}

// handleCombatEncounter runs a single combat roll against a named monster with AI narration.
// POST /api/combat/encounter  {"monster": "Zombie", "stat": 5, "bonus": 0, "character_class": "Brawler", "crit_threshold": 20}
func handleCombatEncounter(w http.ResponseWriter, r *http.Request, aiClient *ai.Client) {
	var req struct {
		Monster        string `json:"monster"`
		Stat           int    `json:"stat"`
		Bonus          int    `json:"bonus"`
		CharacterClass string `json:"character_class"`
		CritThreshold  int    `json:"crit_threshold"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "invalid JSON body", "send {monster,stat,bonus,character_class}")
		return
	}
	if req.Monster == "" {
		writeError(w, http.StatusBadRequest, "MISSING_MONSTER", "monster name required", "use a monster name from the group")
		return
	}
	if req.CharacterClass == "" {
		req.CharacterClass = "Survivor"
	}
	if req.CritThreshold <= 0 {
		req.CritThreshold = 20
	}

	rollReq := game.CombatRollRequest{StatValue: req.Stat, Bonus: req.Bonus}
	result := game.Roll(rollReq, req.CritThreshold)

	// AI narration — 8s timeout, fallback always ready.
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	var narration string
	switch result.Outcome {
	case game.OutcomeCritSuccess, game.OutcomeSuccess:
		isCrit := result.Outcome == game.OutcomeCritSuccess
		narration = aiClient.CombatHit(ctx, req.Monster, req.CharacterClass, isCrit)
		obs.MonstersDefeatedTotal.WithLabelValues(req.Monster).Inc()
	case game.OutcomeCritFailure, game.OutcomeFailure:
		isCritFail := result.Outcome == game.OutcomeCritFailure
		narration = aiClient.CombatMiss(ctx, req.Monster, isCritFail)
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"roll":      result,
		"narration": narration,
		"hit":       result.Outcome == game.OutcomeSuccess || result.Outcome == game.OutcomeCritSuccess,
	})
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

// handleCharacterByID routes all /api/character/:id sub-resources.
//
// Routes:
//   GET  /api/character/:id            — load character
//   PUT  /api/character/:id            — partial update
//   GET  /api/character/:id/sheet      — full sheet with class def
//   POST /api/character/:id/craft      — craft item (consume materials)
//   POST /api/character/:id/equip      — equip item into slot
//   POST /api/character/:id/item/drop  — drop item from inventory
//   POST /api/character/:id/levelup    — server-side LevelUp()
func handleCharacterByID(w http.ResponseWriter, r *http.Request, path string, store *character.Store) {
	trimmed := strings.TrimPrefix(path, "/api/character/")
	parts := strings.SplitN(trimmed, "/", 2)
	id := parts[0]

	if id == "" {
		writeError(w, http.StatusBadRequest, "MISSING_ID", "character ID required", "use /api/character/:id")
		return
	}

	sub := ""
	if len(parts) == 2 {
		sub = parts[1]
	}
	method := r.Method

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

	switch {
	case sub == "" && method == http.MethodGet:
		writeJSON(w, http.StatusOK, c)

	case sub == "" && method == http.MethodPut:
		handleUpdateCharacter(w, r, c, store)

	case sub == "sheet" && method == http.MethodGet:
		classDef := resources.ClassByName(c.Class)
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"character":         c,
			"class_def":         classDef,
			"xp_to_next":        character.XPForNextLevel(c.Level),
			"ready_to_level_up": c.IsReadyToLevelUp(),
			"max_inventory":     c.MaxInventorySlots(),
		})

	case sub == "craft" && method == http.MethodPost:
		handleCraftItem(w, r, c, store)

	case sub == "equip" && method == http.MethodPost:
		handleEquipItem(w, r, c, store)

	case sub == "item/drop" && method == http.MethodPost:
		handleDropItem(w, r, c, store)

	case sub == "levelup" && method == http.MethodPost:
		handleLevelUp(w, r, c, store)

	default:
		writeError(w, http.StatusNotFound, "NOT_FOUND", "route not found", "check path and method")
	}
}

// handleUpdateCharacter applies a partial update to a character.
// PUT /api/character/:id
func handleUpdateCharacter(w http.ResponseWriter, r *http.Request, c *character.Character, store *character.Store) {
	var req struct {
		HP        *int                 `json:"hp,omitempty"`
		XP        *int                 `json:"xp,omitempty"`
		Level     *int                 `json:"level,omitempty"`
		Inventory []string             `json:"inventory,omitempty"`
		Equipment *character.Equipment `json:"equipment,omitempty"`
		Location  string               `json:"location,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "invalid JSON body", "send partial character fields")
		return
	}
	if req.HP != nil {
		c.HP = *req.HP
		if c.HP < 0 {
			c.HP = 0
		}
		if c.HP > c.MaxHP {
			c.HP = c.MaxHP
		}
	}
	if req.XP != nil {
		c.XP = *req.XP
	}
	if req.Level != nil {
		c.Level = *req.Level
	}
	if req.Inventory != nil {
		c.Inventory = req.Inventory
	}
	if req.Equipment != nil {
		c.Equipment = *req.Equipment
	}
	if req.Location != "" {
		c.Location = req.Location
	}
	if err := store.Save(r.Context(), c); err != nil {
		slog.Error("update character failed", "id", c.ID, "error", err)
		writeError(w, http.StatusInternalServerError, "STORE_ERROR", "failed to save character", "check server logs")
		return
	}
	writeJSON(w, http.StatusOK, c)
}

// handleCraftItem crafts an item: verifies materials, consumes them, adds result.
// POST /api/character/:id/craft  {"item_name": "Medkit"}
func handleCraftItem(w http.ResponseWriter, r *http.Request, c *character.Character, store *character.Store) {
	var req struct {
		ItemName string `json:"item_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ItemName == "" {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "item_name required", `send {"item_name": "..."}`)
		return
	}
	item := resources.CraftableItemByName(req.ItemName)
	if item == nil {
		writeError(w, http.StatusBadRequest, "UNKNOWN_ITEM", "item is not craftable", "check /api/items for the craftable list")
		return
	}
	if c.Stats.Crafting < item.CraftingLevel {
		writeError(w, http.StatusBadRequest, "SKILL_TOO_LOW", "crafting stat too low",
			fmt.Sprintf("need crafting %d, have %d", item.CraftingLevel, c.Stats.Crafting))
		return
	}
	if len(c.Inventory) >= c.MaxInventorySlots() {
		writeError(w, http.StatusBadRequest, "INVENTORY_FULL", "inventory is full", "drop an item first")
		return
	}
	// Verify materials (supports duplicate material requirements).
	needed := make(map[string]int)
	for _, mat := range item.Materials {
		needed[mat]++
	}
	have := make(map[string]int)
	for _, inv := range c.Inventory {
		have[inv]++
	}
	for mat, count := range needed {
		if have[mat] < count {
			writeError(w, http.StatusBadRequest, "MISSING_MATERIALS",
				fmt.Sprintf("missing %d x %s", count-have[mat], mat),
				"check your inventory for required materials")
			return
		}
	}
	for _, mat := range item.Materials {
		c.RemoveFirstItem(mat)
	}
	c.Inventory = append(c.Inventory, item.Name)
	if err := store.Save(r.Context(), c); err != nil {
		slog.Error("craft save failed", "id", c.ID, "error", err)
		writeError(w, http.StatusInternalServerError, "STORE_ERROR", "failed to save after craft", "check server logs")
		return
	}
	writeJSON(w, http.StatusOK, c)
}

// handleEquipItem sets a character's equipment slot.
// POST /api/character/:id/equip  {"slot": "weapon", "item": "Reinforced Bat"}
// Send item:"" to unequip.
func handleEquipItem(w http.ResponseWriter, r *http.Request, c *character.Character, store *character.Store) {
	var req struct {
		Slot string `json:"slot"` // weapon | armor | accessory
		Item string `json:"item"` // item name or "" to unequip
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "invalid body", `send {"slot":"weapon|armor|accessory","item":"..."}`)
		return
	}
	validSlots := map[string]bool{"weapon": true, "armor": true, "accessory": true}
	if !validSlots[req.Slot] {
		writeError(w, http.StatusBadRequest, "INVALID_SLOT", "slot must be weapon, armor, or accessory", "")
		return
	}
	if req.Item != "" && !c.ContainsItem(req.Item) {
		writeError(w, http.StatusBadRequest, "NOT_IN_INVENTORY", "item not in inventory", "you can only equip items you're carrying")
		return
	}
	switch req.Slot {
	case "weapon":
		c.Equipment.Weapon = req.Item
	case "armor":
		c.Equipment.Armor = req.Item
	case "accessory":
		c.Equipment.Accessory = req.Item
	}
	if err := store.Save(r.Context(), c); err != nil {
		slog.Error("equip save failed", "id", c.ID, "error", err)
		writeError(w, http.StatusInternalServerError, "STORE_ERROR", "failed to save after equip", "check server logs")
		return
	}
	writeJSON(w, http.StatusOK, c)
}

// handleDropItem removes an item from inventory and auto-unequips it.
// POST /api/character/:id/item/drop  {"item_name": "Bandage"}
func handleDropItem(w http.ResponseWriter, r *http.Request, c *character.Character, store *character.Store) {
	var req struct {
		ItemName string `json:"item_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ItemName == "" {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "item_name required", `send {"item_name": "..."}`)
		return
	}
	if !c.RemoveFirstItem(req.ItemName) {
		writeError(w, http.StatusBadRequest, "NOT_IN_INVENTORY", "item not in inventory", "nothing to drop")
		return
	}
	// Auto-unequip from any slot.
	if c.Equipment.Weapon == req.ItemName {
		c.Equipment.Weapon = ""
	}
	if c.Equipment.Armor == req.ItemName {
		c.Equipment.Armor = ""
	}
	if c.Equipment.Accessory == req.ItemName {
		c.Equipment.Accessory = ""
	}
	if err := store.Save(r.Context(), c); err != nil {
		slog.Error("drop save failed", "id", c.ID, "error", err)
		writeError(w, http.StatusInternalServerError, "STORE_ERROR", "failed to save after drop", "check server logs")
		return
	}
	writeJSON(w, http.StatusOK, c)
}

// handleLevelUp calls LevelUp() server-side and persists the result.
// POST /api/character/:id/levelup
func handleLevelUp(w http.ResponseWriter, r *http.Request, c *character.Character, store *character.Store) {
	if !c.IsReadyToLevelUp() {
		writeError(w, http.StatusBadRequest, "NOT_READY", "not enough XP to level up",
			fmt.Sprintf("need %d XP, currently have %d", character.XPForNextLevel(c.Level), c.XP))
		return
	}
	c.LevelUp()
	if err := store.Save(r.Context(), c); err != nil {
		slog.Error("levelup save failed", "id", c.ID, "error", err)
		writeError(w, http.StatusInternalServerError, "STORE_ERROR", "failed to save after level up", "check server logs")
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
	case strings.HasPrefix(path, "/api/building/"):
		return "/api/building/:action"
	case strings.HasPrefix(path, "/api/combat/"):
		return "/api/combat/:action"
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
