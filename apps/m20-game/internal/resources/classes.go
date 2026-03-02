// Package resources holds all static game data: classes, monsters, tiles, etc.
package resources

// CharacterClass represents one of the eight playable classes.
type CharacterClass struct {
	Name           string            `json:"name"`
	Flavor         string            `json:"flavor"`
	BonusStats     map[string]int    `json:"bonus_stats"`
	SpecialAbility string            `json:"special_ability"`
	BaseStats      map[string]int    `json:"base_stats"`
}

// Classes returns all eight playable character classes.
func Classes() []CharacterClass {
	base := map[string]int{
		"strength":     3,
		"stamina":      3,
		"marksmanship": 3,
		"scouting":     3,
		"scavenging":   3,
		"crafting":     3,
		"salvaging":    3,
	}

	copyBase := func() map[string]int {
		m := make(map[string]int, len(base))
		for k, v := range base {
			m[k] = v
		}
		return m
	}

	classes := []CharacterClass{
		{
			Name:   "Scavenger",
			Flavor: "Trash is treasure",
			BonusStats: map[string]int{
				"scavenging": 3,
				"scouting":   2,
			},
			SpecialAbility: "Find extra supplies on scavenge rolls",
			BaseStats:      copyBase(),
		},
		{
			Name:   "Medic",
			Flavor: "Do no harm... to the living",
			BonusStats: map[string]int{
				"stamina":  3,
				"crafting": 2,
			},
			SpecialAbility: "Heal self mid-combat once per fight",
			BaseStats:      copyBase(),
		},
		{
			Name:   "Gunslinger",
			Flavor: "I never miss twice",
			BonusStats: map[string]int{
				"marksmanship": 4,
				"scouting":     1,
			},
			SpecialAbility: "First strike bonus — always acts first in combat",
			BaseStats:      copyBase(),
		},
		{
			Name:   "Wrench Witch",
			Flavor: "It's not broken, it's in progress",
			BonusStats: map[string]int{
				"crafting":  4,
				"salvaging": 2,
			},
			SpecialAbility: "Build vehicles faster and at lower material cost",
			BaseStats:      copyBase(),
		},
		{
			Name:   "Brawler",
			Flavor: "I am the blunt instrument",
			BonusStats: map[string]int{
				"strength": 4,
				"stamina":  2,
			},
			SpecialAbility: "Critical hit threshold reduced by 2",
			BaseStats:      copyBase(),
		},
		{
			Name:   "Conspiracy Theorist",
			Flavor: "The Sphinx is a GOVERNMENT PROJECT",
			BonusStats: map[string]int{
				"scouting":   2,
				"scavenging": 2,
			},
			SpecialAbility: "Advantage on Sphinx riddle checks (+3 to roll)",
			BaseStats:      copyBase(),
		},
		{
			Name:   "Hoarder",
			Flavor: "I might need this someday",
			BonusStats: map[string]int{
				"salvaging": 3,
				"crafting":  1,
			},
			SpecialAbility: "+3 inventory slots (8 total instead of 5)",
			BaseStats:      copyBase(),
		},
		{
			Name:   "Street Pharmacist",
			Flavor: "I have something for that",
			BonusStats: map[string]int{
				"crafting": 3,
				"stamina":  2,
			},
			SpecialAbility: "Craft medical items at one tier below required level",
			BaseStats:      copyBase(),
		},
	}

	// Apply bonus stats on top of base stats
	for i := range classes {
		for stat, bonus := range classes[i].BonusStats {
			classes[i].BaseStats[stat] += bonus
		}
	}

	return classes
}

// ClassByName returns a class definition or nil if not found.
func ClassByName(name string) *CharacterClass {
	for _, c := range Classes() {
		if c.Name == name {
			return &c
		}
	}
	return nil
}
