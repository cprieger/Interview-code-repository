package game

import "fmt"

// Land is a generated map composed of multiple tiles.
type Land struct {
	Tiles     []Tile `json:"tiles"`
	TileCount int    `json:"tile_count"`
}

// GenerateLand creates a map with tileCount tiles.
// tileCount is clamped between 1 and 25.
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

	return Land{
		Tiles:     tiles,
		TileCount: tileCount,
	}
}
