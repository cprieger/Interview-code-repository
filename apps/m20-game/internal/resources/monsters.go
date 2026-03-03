package resources

// Monster defines a dungeon encounter.
type Monster struct {
	Name        string `json:"name"`
	HP          int    `json:"hp"`
	Attack      int    `json:"attack"`      // bonus added to monster's d20 roll
	Defense     int    `json:"defense"`     // target number player must beat
	XPReward    int    `json:"xp_reward"`
	Description string `json:"description"`
	HasRiddle   bool   `json:"has_riddle"` // true for Sphinx — triggers Ollama AI
}

// Monsters returns the ten public-domain folkloric monsters.
func Monsters() []Monster {
	return []Monster{
		{
			Name:        "Zombie",
			HP:          8,
			Attack:      1,
			Defense:     8,
			XPReward:    50,
			Description: "Slow but relentless. It will not stop until one of you does.",
		},
		{
			Name:        "Werewolf",
			HP:          14,
			Attack:      4,
			Defense:     12,
			XPReward:    150,
			Description: "Bound by the moon, freed by rage. Silver is your only friend.",
		},
		{
			Name:        "Vampire",
			HP:          16,
			Attack:      5,
			Defense:     14,
			XPReward:    200,
			Description: "Aristocratic. Dangerous. Has opinions about your neck.",
		},
		{
			Name:        "Mummy",
			HP:          12,
			Attack:      3,
			Defense:     11,
			XPReward:    120,
			Description: "Wrapped in ancient curses. Surprisingly fast for a dead person.",
		},
		{
			Name:        "Frankenstein",
			HP:          20,
			Attack:      5,
			Defense:     10,
			XPReward:    250,
			Description: "Assembled from the best parts of the worst people.",
		},
		{
			Name:        "Basilisk",
			HP:          18,
			Attack:      6,
			Defense:     13,
			XPReward:    220,
			Description: "Do not make eye contact. Seriously. Don't.",
		},
		{
			Name:        "Golem",
			HP:          25,
			Attack:      4,
			Defense:     16,
			XPReward:    300,
			Description: "A creature of clay and purpose. It has one job and it's very good at it.",
		},
		{
			Name:        "Sphinx",
			HP:          22,
			Attack:      7,
			Defense:     15,
			XPReward:    400,
			Description: "Answer the riddle or suffer the consequences.",
			HasRiddle:   true,
		},
		{
			Name:        "Wraith",
			HP:          15,
			Attack:      6,
			Defense:     14,
			XPReward:    180,
			Description: "The cold feeling you get before it's too late.",
		},
		{
			Name:        "Windego",
			HP:          30,
			Attack:      8,
			Defense:     17,
			XPReward:    500,
			Description: "It was once human. That was a long time ago.",
		},
	}
}

// MonsterByName returns a monster definition or nil if not found.
func MonsterByName(name string) *Monster {
	for _, m := range Monsters() {
		if m.Name == name {
			return &m
		}
	}
	return nil
}
