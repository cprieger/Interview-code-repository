package resources

// Building represents a structure found on a tile.
type Building struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Loot        []string `json:"loot"`       // possible item names
	Danger      int      `json:"danger"`
}

// Buildings returns all discoverable building types.
func Buildings() []Building {
	return []Building{
		{
			Name:        "Pharmacy",
			Description: "Most of the medication is expired. Most.",
			Loot:        []string{"Bandage", "Antibiotics", "Painkillers"},
			Danger:      1,
		},
		{
			Name:        "Hardware Store",
			Description: "A gold mine for anyone who knows what a torque wrench is.",
			Loot:        []string{"Scrap Metal", "Wire", "Duct Tape", "Tools"},
			Danger:      1,
		},
		{
			Name:        "Police Station",
			Description: "Cleared out. Mostly. The holding cells had a surprise.",
			Loot:        []string{"First Aid Kit", "Riot Gear Fragment", "Radio Parts"},
			Danger:      3,
		},
		{
			Name:        "School",
			Description: "The cafeteria is surprisingly well-stocked.",
			Loot:        []string{"Canned Food", "Bandage", "Wire"},
			Danger:      2,
		},
		{
			Name:        "Auto Repair Shop",
			Description: "Half-assembled vehicle in the bay. Owner left in a hurry.",
			Loot:        []string{"Engine Parts", "Fuel", "Scrap Metal", "Tools"},
			Danger:      1,
		},
		{
			Name:        "Supermarket",
			Description: "Picked over, but the back room was locked.",
			Loot:        []string{"Canned Food", "Water Filter", "Bandage"},
			Danger:      2,
		},
	}
}
