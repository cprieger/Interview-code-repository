package game

// Land is a generated map composed of multiple tiles.
type Land struct {
	Tiles     []Tile `json:"tiles"`
	TileCount int    `json:"tile_count"`
}
