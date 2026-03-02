package game

import (
	"math/rand"

	"m20-game/internal/resources"
)

// MonsterEncounter holds the resolved monster and combat context.
type MonsterEncounter struct {
	Monster   resources.Monster `json:"monster"`
	HasRiddle bool              `json:"has_riddle"`
	TileID    string            `json:"tile_id,omitempty"`
}

// RandomEncounter picks a random monster for a standard encounter.
func RandomEncounter(tileID string) MonsterEncounter {
	monsters := resources.Monsters()
	m := monsters[rand.Intn(len(monsters))]
	return MonsterEncounter{
		Monster:   m,
		HasRiddle: m.HasRiddle,
		TileID:    tileID,
	}
}

// EncounterByName returns a specific monster encounter by name.
func EncounterByName(name, tileID string) *MonsterEncounter {
	m := resources.MonsterByName(name)
	if m == nil {
		return nil
	}
	return &MonsterEncounter{
		Monster:   *m,
		HasRiddle: m.HasRiddle,
		TileID:    tileID,
	}
}
