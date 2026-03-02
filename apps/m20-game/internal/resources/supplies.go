package resources

// Supply is a scavenged item found in the world.
type Supply struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Category    string `json:"category"` // medical | material | food | fuel
	Rarity      int    `json:"rarity"`   // 1 (common) to 5 (rare)
}

// CraftableItem is something the player can build from components.
type CraftableItem struct {
	Name         string   `json:"name"`
	Description  string   `json:"description"`
	Materials    []string `json:"materials"`
	CraftingLevel int     `json:"crafting_level"` // minimum crafting stat required
}

// Supplies returns all scavengeable items.
func Supplies() []Supply {
	return []Supply{
		{Name: "Bandage", Description: "Stops the bleeding. Doesn't stop the cause.", Category: "medical", Rarity: 1},
		{Name: "Antibiotics", Description: "Fight infection the old-fashioned way.", Category: "medical", Rarity: 3},
		{Name: "Painkillers", Description: "Numbs the pain. Also your judgment.", Category: "medical", Rarity: 2},
		{Name: "First Aid Kit", Description: "Everything a medic needs except experience.", Category: "medical", Rarity: 3},
		{Name: "Scrap Metal", Description: "Twisted, rusted, and beautiful.", Category: "material", Rarity: 1},
		{Name: "Wire", Description: "Electrical or structural — your call.", Category: "material", Rarity: 1},
		{Name: "Duct Tape", Description: "Fixes 80% of problems permanently.", Category: "material", Rarity: 2},
		{Name: "Tools", Description: "Generic toolkit. Surprisingly rare.", Category: "material", Rarity: 2},
		{Name: "Engine Parts", Description: "You're not sure what most of these do.", Category: "material", Rarity: 3},
		{Name: "Radio Parts", Description: "Maybe someone's still broadcasting.", Category: "material", Rarity: 3},
		{Name: "Canned Food", Description: "Expires never. Tastes accordingly.", Category: "food", Rarity: 1},
		{Name: "Water Filter", Description: "Turns pond water into merely suspicious water.", Category: "food", Rarity: 3},
		{Name: "Fuel", Description: "Vehicles need it. So does morale.", Category: "fuel", Rarity: 2},
		{Name: "Riot Gear Fragment", Description: "Protection without the riot.", Category: "material", Rarity: 4},
	}
}

// CraftableItems returns all items that can be built from components.
func CraftableItems() []CraftableItem {
	return []CraftableItem{
		{
			Name:          "Improvised Armor",
			Description:   "Scrap metal duct-taped to a vest. Better than nothing.",
			Materials:     []string{"Scrap Metal", "Duct Tape", "Wire"},
			CraftingLevel: 4,
		},
		{
			Name:          "Molotov Cocktail",
			Description:   "Simple, effective, and very hard to un-throw.",
			Materials:     []string{"Fuel", "Duct Tape"},
			CraftingLevel: 2,
		},
		{
			Name:          "Medkit",
			Description:   "An upgrade from the basic bandage. Restores more HP.",
			Materials:     []string{"Bandage", "Antibiotics", "Painkillers"},
			CraftingLevel: 3,
		},
		{
			Name:          "Radio Beacon",
			Description:   "Calls for help. Whether help comes is another question.",
			Materials:     []string{"Radio Parts", "Wire", "Tools"},
			CraftingLevel: 5,
		},
		{
			Name:          "Reinforced Bat",
			Description:   "A classic, improved.",
			Materials:     []string{"Scrap Metal", "Wire"},
			CraftingLevel: 2,
		},
		{
			Name:          "Vehicle Repair Kit",
			Description:   "Patches up your ride enough to keep moving.",
			Materials:     []string{"Engine Parts", "Duct Tape", "Tools"},
			CraftingLevel: 4,
		},
	}
}

// CanCraft returns items craftable from the given materials at the given crafting level.
func CanCraft(materials []string, craftingLevel int) []CraftableItem {
	matSet := make(map[string]bool)
	for _, m := range materials {
		matSet[m] = true
	}

	var result []CraftableItem
	for _, item := range CraftableItems() {
		if item.CraftingLevel > craftingLevel {
			continue
		}
		canMake := true
		for _, required := range item.Materials {
			if !matSet[required] {
				canMake = false
				break
			}
		}
		if canMake {
			result = append(result, item)
		}
	}
	return result
}
