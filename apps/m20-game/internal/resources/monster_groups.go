package resources

// MonsterGroup is a thematically coherent set of monsters in a building.
// Groups feel like they belong together — vampires keep watch, zombies shamble in herds.
type MonsterGroup struct {
	Name        string    `json:"name"`
	Description string    `json:"description"` // narrative setup before combat
	Monsters    []Monster `json:"monsters"`    // ordered: weakest first, boss last
	Difficulty  int       `json:"difficulty"`  // 1-5
	MinLevel    int       `json:"min_level"`   // suggested minimum character level
	TotalXP     int       `json:"total_xp"`
}

// buildingGroups maps building names to the monster groups that inhabit them.
// Each building has 2-3 possible groups — randomised on generation.
var buildingGroups = map[string][]MonsterGroup{
	"Hospital": {
		{
			Name:        "Frankenstein's Lab",
			Description: "The operating theater has been repurposed. Surgical lights flicker over a table covered in mismatched limbs. Something massive turns toward you.",
			Difficulty:  4,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
				*MonsterByName("Frankenstein"),
			},
		},
		{
			Name:        "Zombie Ward",
			Description: "They're still in their gowns. IV drips trail behind them. The whole floor groans as they turn in unison.",
			Difficulty:  2,
			MinLevel:    1,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
			},
		},
		{
			Name:        "Wraith Wing",
			Description: "The cold hits before anything else. The lights died here weeks ago. Something that used to be a patient drifts toward you — barely visible, already angry.",
			Difficulty:  3,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Wraith"),
			},
		},
	},
	"Pharmacy": {
		{
			Name:        "Zombie Stragglers",
			Description: "Two of them are still reaching for shelves. Old habits. They haven't noticed you yet.",
			Difficulty:  1,
			MinLevel:    1,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
			},
		},
		{
			Name:        "Vampire Supplier",
			Description: "The shelves have been organized meticulously — blood thinners in the front, anticoagulants in back. The clerk smiles too wide when they see you.",
			Difficulty:  3,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Vampire"),
			},
		},
	},
	"Hardware Store": {
		{
			Name:        "Golem Sentinels",
			Description: "Someone built them from rebar and concrete mix. They stand perfectly still until you cross the threshold.",
			Difficulty:  3,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Golem"),
				*MonsterByName("Golem"),
			},
		},
		{
			Name:        "Zombie Work Crew",
			Description: "Hard hats. Visibility vests. Three of them are still 'working' — swinging hammers at nothing in particular.",
			Difficulty:  2,
			MinLevel:    1,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
			},
		},
	},
	"Police Station": {
		{
			Name:        "Vampire Detective",
			Description: "The booking desk is immaculate. A figure in a detective's coat doesn't look up from the files. 'We've been expecting someone like you,' they say.",
			Difficulty:  4,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Wraith"),
				*MonsterByName("Vampire"),
			},
		},
		{
			Name:        "Zombie Officers",
			Description: "Still in uniform. Still reaching for holsters that are empty. The holding cells are locked — whatever's in there is staying in there.",
			Difficulty:  2,
			MinLevel:    1,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
			},
		},
		{
			Name:        "Golem Guards",
			Description: "Built from cruiser doors and body armor. Someone put a lot of thought into this. The badge on the largest one says 'Chief.'",
			Difficulty:  4,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Golem"),
				*MonsterByName("Golem"),
			},
		},
	},
	"School": {
		{
			Name:        "Zombie Classroom",
			Description: "Still seated. Still facing the board. The chalk squeaks as one of them writes the same word over and over. You don't want to read it.",
			Difficulty:  2,
			MinLevel:    1,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
			},
		},
		{
			Name:        "Mummy's Lesson",
			Description: "The ancient bandaged thing stands at the front of the class like it's been there for centuries. Given the smell, maybe it has.",
			Difficulty:  3,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Mummy"),
			},
		},
		{
			Name:        "Werewolf Pack",
			Description: "The gymnasium. The bleachers are shredded. Three of them pace the basketball court and their heads snap up in unison when you open the door.",
			Difficulty:  4,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Werewolf"),
				*MonsterByName("Werewolf"),
				*MonsterByName("Werewolf"),
			},
		},
	},
	"Auto Repair Shop": {
		{
			Name:        "Zombie Mechanics",
			Description: "Three of them are still working on a car that hasn't had an engine for months. The repetitive sound of metal on metal is somehow worse than silence.",
			Difficulty:  1,
			MinLevel:    1,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
			},
		},
		{
			Name:        "Golem Repair Crew",
			Description: "Assembled from engine blocks and exhaust pipes. One of them is holding a wrench the size of your arm. They were built to fix things. You are a thing that needs fixing.",
			Difficulty:  4,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Golem"),
			},
		},
	},
	"Supermarket": {
		{
			Name:        "Zombie Shoppers",
			Description: "They still push carts. The wheels squeak on linoleum. There are four of them, browsing aisles that haven't had stock in months.",
			Difficulty:  2,
			MinLevel:    1,
			Monsters: []Monster{
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
				*MonsterByName("Zombie"),
			},
		},
		{
			Name:        "Vampire Management",
			Description: "The back office light is on. Two of them sit at a table reviewing inventory logs — blood units, not produce. The manager looks up. 'We're not open,' it says.",
			Difficulty:  4,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Wraith"),
				*MonsterByName("Vampire"),
				*MonsterByName("Vampire"),
			},
		},
		{
			Name:        "Undead Stock Team",
			Description: "Mixed crew. A mummy restocking canned goods. Two zombies blocking the exit. A wraith drifting through the frozen section.",
			Difficulty:  3,
			MinLevel:    2,
			Monsters: []Monster{
				*MonsterByName("Mummy"),
				*MonsterByName("Zombie"),
				*MonsterByName("Wraith"),
			},
		},
	},
}

// GroupsForBuilding returns the available monster groups for a building.
// Falls back to a generic zombie encounter if the building has no entry.
func GroupsForBuilding(buildingName string) []MonsterGroup {
	groups, ok := buildingGroups[buildingName]
	if !ok || len(groups) == 0 {
		return []MonsterGroup{genericZombieGroup()}
	}
	return groups
}

// RandomGroupForBuilding picks one monster group for the given building.
func RandomGroupForBuilding(buildingName string) MonsterGroup {
	groups := GroupsForBuilding(buildingName)
	return groups[randN(len(groups))]
}

func genericZombieGroup() MonsterGroup {
	return MonsterGroup{
		Name:        "Zombie Remnants",
		Description: "Whatever lived here before is gone. What's left shuffles toward you.",
		Difficulty:  1,
		MinLevel:    1,
		Monsters: []Monster{
			*MonsterByName("Zombie"),
			*MonsterByName("Zombie"),
		},
	}
}

// computeTotalXP sums XP rewards across a group's monsters.
func (g *MonsterGroup) ComputeTotalXP() int {
	total := 0
	for _, m := range g.Monsters {
		total += m.XPReward
	}
	return total
}

// SpecialGroups are only found in specific tile types, not buildings.
var SpecialGroups = map[string]MonsterGroup{
	"Sphinx Chamber": {
		Name:        "Sphinx Chamber",
		Description: "The chamber is perfectly circular. Torchlight catches carved riddles in the walls — none of them answered. The Sphinx has been waiting a long time.",
		Difficulty:  5,
		MinLevel:    3,
		Monsters:    []Monster{*MonsterByName("Sphinx")},
	},
	"Windego Den": {
		Name:        "Windego Den",
		Description: "Bones. So many bones. Something vast and wrong unfolds itself from the darkness at the end of the passage.",
		Difficulty:  5,
		MinLevel:    4,
		Monsters:    []Monster{*MonsterByName("Windego")},
	},
	"Vampire Nest": {
		Name:        "Vampire Nest",
		Description: "Coffins. Of course coffins. Three of them, and the lids are already open. They were waiting for you.",
		Difficulty:  4,
		MinLevel:    2,
		Monsters: []Monster{
			*MonsterByName("Vampire"),
			*MonsterByName("Vampire"),
			*MonsterByName("Wraith"),
		},
	},
	"Werewolf Pack": {
		Name:        "Werewolf Pack",
		Description: "You smell them before you see them. Three shapes pace the far end of the space, growling low. The largest one turns first.",
		Difficulty:  4,
		MinLevel:    2,
		Monsters: []Monster{
			*MonsterByName("Werewolf"),
			*MonsterByName("Werewolf"),
			*MonsterByName("Werewolf"),
		},
	},
	"Basilisk Lair": {
		Name:        "Basilisk Lair",
		Description: "The stone floor is littered with shapes that were once people. You keep your eyes down as you enter. The Basilisk is somewhere ahead. Don't look up.",
		Difficulty:  5,
		MinLevel:    3,
		Monsters: []Monster{
			*MonsterByName("Wraith"),
			*MonsterByName("Basilisk"),
		},
	},
}
