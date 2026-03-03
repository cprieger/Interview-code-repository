package game

import (
	"fmt"
	"math/rand"

	"m20-game/internal/obs"
	"m20-game/internal/resources"
)

// BuildingInstance is one building on a tile, pre-populated with its monster group.
type BuildingInstance struct {
	Building     resources.Building    `json:"building"`
	MonsterGroup resources.MonsterGroup `json:"monster_group"`
	Cleared      bool                  `json:"cleared"` // true after players defeat the group
}

// Tile is a generated map tile with 2-4 buildings, each holding a monster group.
type Tile struct {
	ID        string             `json:"id"`
	Type      resources.TileType `json:"type"`
	Buildings []BuildingInstance `json:"buildings"`
	Explored  bool               `json:"explored"`
}

// GenerateTile picks a random tile type and populates it with buildings and monster groups.
func GenerateTile(id string) Tile {
	allTiles := resources.Tiles()
	t := allTiles[rand.Intn(len(allTiles))]

	// Danger 1-2 → 2 buildings; danger 3 → 3 buildings; danger 4-5 → 4 buildings.
	buildingCount := 2
	if t.Danger >= 3 {
		buildingCount = 3
	}
	if t.Danger >= 4 {
		buildingCount = 4
	}

	allBuildings := resources.Buildings()
	// Shuffle and pick N (with possible repeats only if fewer buildings than count).
	rand.Shuffle(len(allBuildings), func(i, j int) { allBuildings[i], allBuildings[j] = allBuildings[j], allBuildings[i] })
	if buildingCount > len(allBuildings) {
		buildingCount = len(allBuildings)
	}

	instances := make([]BuildingInstance, buildingCount)
	for i := 0; i < buildingCount; i++ {
		b := allBuildings[i]
		g := resources.RandomGroupForBuilding(b.Name)
		g.TotalXP = g.ComputeTotalXP()
		instances[i] = BuildingInstance{
			Building:     b,
			MonsterGroup: g,
			Cleared:      false,
		}
	}

	obs.TilesGeneratedTotal.WithLabelValues(t.Name).Inc()

	return Tile{
		ID:        id,
		Type:      t,
		Buildings: instances,
		Explored:  false,
	}
}

// GenerateSingleBuilding generates one building encounter by name (for /api/building/enter).
// If buildingName is empty, picks at random.
func GenerateSingleBuilding(buildingName string) BuildingInstance {
	allBuildings := resources.Buildings()

	var b resources.Building
	if buildingName != "" {
		for _, bld := range allBuildings {
			if bld.Name == buildingName {
				b = bld
				break
			}
		}
	}
	if b.Name == "" {
		b = allBuildings[rand.Intn(len(allBuildings))]
	}

	g := resources.RandomGroupForBuilding(b.Name)
	g.TotalXP = g.ComputeTotalXP()

	return BuildingInstance{
		Building:     b,
		MonsterGroup: g,
		Cleared:      false,
	}
}

// GenerateLand creates a map with tileCount tiles, each fully populated.
func GenerateLand(tileCount int) Land {
	if tileCount < 1 {
		tileCount = 1
	}
	if tileCount > 25 {
		tileCount = 25
	}
	tiles := make([]Tile, tileCount)
	for i := range tiles {
		tiles[i] = GenerateTile(fmt.Sprintf("tile-%02d", i+1))
	}
	return Land{Tiles: tiles, TileCount: tileCount}
}
