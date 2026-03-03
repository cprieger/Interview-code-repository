package resources

// EquipBonuses maps equippable item names to the per-stat bonuses they grant.
// Using map[string]int per item avoids an import cycle between resources ↔ character.
// Keys match the CharacterStats JSON field names (lowercase).
var EquipBonuses = map[string]map[string]int{
	"Reinforced Bat":     {"strength": 2},
	"Improvised Armor":   {"stamina": 3},
	"Medkit":             {"stamina": 1},
	"Radio Beacon":       {"scouting": 2},
	"Vehicle Repair Kit": {"salvaging": 2, "crafting": 1},
}

// EquipSlots returns the three valid equipment slot names.
func EquipSlots() []string {
	return []string{"weapon", "armor", "accessory"}
}

// EquippableItems returns all item names that can be equipped.
func EquippableItems() []string {
	names := make([]string, 0, len(EquipBonuses))
	for name := range EquipBonuses {
		names = append(names, name)
	}
	return names
}

// IsEquippable returns true if the named item can be equipped.
func IsEquippable(itemName string) bool {
	_, ok := EquipBonuses[itemName]
	return ok
}
