package game

import (
	"math/rand"

	"m20-game/internal/obs"
	"m20-game/internal/resources"
)

// Tile is a generated map tile with its encounter type resolved.
type Tile struct {
	ID          string            `json:"id"`
	Type        resources.TileType `json:"type"`
	EncounterType string          `json:"encounter_type"` // monster | supply | building | vehicle | empty
	Explored    bool              `json:"explored"`
}

// GenerateTile picks a random tile type and resolves one encounter.
func GenerateTile(id string) Tile {
	tiles := resources.Tiles()
	t := tiles[rand.Intn(len(tiles))]

	encounterType := "empty"
	if len(t.Encounters) > 0 {
		encounterType = t.Encounters[rand.Intn(len(t.Encounters))]
	}

	obs.TilesGeneratedTotal.WithLabelValues(t.Name).Inc()

	return Tile{
		ID:            id,
		Type:          t,
		EncounterType: encounterType,
		Explored:      false,
	}
}
