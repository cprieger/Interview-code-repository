package game

import (
	"math/rand"

	"m20-game/internal/resources"
)

// BuildingExploreResult is the outcome of entering a building.
type BuildingExploreResult struct {
	Building    resources.Building `json:"building"`
	LootFound   []string           `json:"loot_found"`
	HasMonster  bool               `json:"has_monster"`
	Description string             `json:"description"`
}

// ExploreBuilding enters a random building and determines loot and danger.
func ExploreBuilding() BuildingExploreResult {
	buildings := resources.Buildings()
	b := buildings[rand.Intn(len(buildings))]

	// Danger level (1-5) determines chance of monster encounter.
	hasMonster := rand.Intn(5)+1 <= b.Danger

	// Loot: pick 1-3 items from the building's loot table.
	count := rand.Intn(len(b.Loot)) + 1
	if count > 3 {
		count = 3
	}
	shuffled := make([]string, len(b.Loot))
	copy(shuffled, b.Loot)
	rand.Shuffle(len(shuffled), func(i, j int) { shuffled[i], shuffled[j] = shuffled[j], shuffled[i] })

	desc := b.Description
	if hasMonster {
		desc += " You're not alone in here."
	}

	return BuildingExploreResult{
		Building:    b,
		LootFound:   shuffled[:count],
		HasMonster:  hasMonster,
		Description: desc,
	}
}
