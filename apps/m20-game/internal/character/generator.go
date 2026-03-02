package character

import (
	"fmt"
	"math/rand"
	"time"

	"github.com/google/uuid"
	"m20-game/internal/obs"
	"m20-game/internal/resources"
)

// GenerateRequest is the input for character creation.
type GenerateRequest struct {
	Name  string `json:"name"`   // required
	Class string `json:"class"`  // optional — random if empty
}

// Generate creates a new Character from a request.
// If Class is empty, one is assigned at random.
// Stats are loaded from the class definition.
func Generate(req GenerateRequest) (*Character, error) {
	if req.Name == "" {
		return nil, fmt.Errorf("name is required")
	}

	class := req.Class
	if class == "" {
		classes := resources.Classes()
		class = classes[rand.Intn(len(classes))].Name
	}

	classDef := resources.ClassByName(class)
	if classDef == nil {
		return nil, fmt.Errorf("unknown class: %s", class)
	}

	stats := CharacterStats{
		Strength:     classDef.BaseStats["strength"],
		Stamina:      classDef.BaseStats["stamina"],
		Marksmanship: classDef.BaseStats["marksmanship"],
		Scouting:     classDef.BaseStats["scouting"],
		Scavenging:   classDef.BaseStats["scavenging"],
		Crafting:     classDef.BaseStats["crafting"],
		Salvaging:    classDef.BaseStats["salvaging"],
	}

	// Cap stats at 10
	capStat := func(v int) int {
		if v > 10 {
			return 10
		}
		return v
	}
	stats.Strength = capStat(stats.Strength)
	stats.Stamina = capStat(stats.Stamina)
	stats.Marksmanship = capStat(stats.Marksmanship)
	stats.Scouting = capStat(stats.Scouting)
	stats.Scavenging = capStat(stats.Scavenging)
	stats.Crafting = capStat(stats.Crafting)
	stats.Salvaging = capStat(stats.Salvaging)

	maxHP := 10 + stats.Stamina

	now := time.Now().UTC()
	c := &Character{
		ID:        uuid.New().String(),
		Name:      req.Name,
		Class:     class,
		Level:     1,
		XP:        0,
		HP:        maxHP,
		MaxHP:     maxHP,
		Stats:     stats,
		Inventory: []string{},
		Location:  "tile-01",
		CreatedAt: now,
		UpdatedAt: now,
	}

	obs.CharactersCreatedTotal.WithLabelValues(class).Inc()

	return c, nil
}
