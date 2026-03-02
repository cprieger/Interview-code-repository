package resources

// TileType describes the kind of terrain on a map tile.
type TileType struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Encounters  []string `json:"encounters"` // what can be found here
	Danger      int      `json:"danger"`     // 1-5 scale
}

// Tiles returns the full set of tile types for procedural map generation.
func Tiles() []TileType {
	return []TileType{
		{
			Name:        "Ruined City Block",
			Description: "Collapsed concrete and broken glass. Something moved in the shadows.",
			Encounters:  []string{"monster", "supply", "building"},
			Danger:      3,
		},
		{
			Name:        "Overgrown Highway",
			Description: "The old road still goes somewhere. Probably somewhere bad.",
			Encounters:  []string{"vehicle", "supply", "monster"},
			Danger:      2,
		},
		{
			Name:        "Abandoned Suburb",
			Description: "Identical houses, identical despair. At least the garages have stuff.",
			Encounters:  []string{"supply", "building", "monster"},
			Danger:      2,
		},
		{
			Name:        "Gas Station",
			Description: "Empty pumps, full shelves (mostly). The bathroom is a biohazard.",
			Encounters:  []string{"supply", "vehicle"},
			Danger:      1,
		},
		{
			Name:        "Hospital",
			Description: "Medical supplies. Also whatever set up residence in ward C.",
			Encounters:  []string{"supply", "monster", "building"},
			Danger:      4,
		},
		{
			Name:        "Underground Parking",
			Description: "Vehicles aplenty. Visibility: zero. Echoes: maximum.",
			Encounters:  []string{"vehicle", "monster"},
			Danger:      3,
		},
		{
			Name:        "Forest Edge",
			Description: "Trees don't judge. Neither does whatever's watching from them.",
			Encounters:  []string{"monster", "supply"},
			Danger:      2,
		},
		{
			Name:        "Military Outpost",
			Description: "Abandoned but not empty. The armory might still have something useful.",
			Encounters:  []string{"supply", "monster", "building"},
			Danger:      4,
		},
		{
			Name:        "Shopping Mall",
			Description: "The apocalypse hit mid-sale. Everything's 100% off.",
			Encounters:  []string{"supply", "building", "monster", "vehicle"},
			Danger:      3,
		},
		{
			Name:        "Dungeon Entrance",
			Description: "A staircase descends. There is no light below. This is the way.",
			Encounters:  []string{"monster"},
			Danger:      5,
		},
	}
}
