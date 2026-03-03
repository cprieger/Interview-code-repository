package game

import (
	"math/rand"

	"m20-game/internal/resources"
)

// ScavengeResult is the outcome of a scavenging attempt.
type ScavengeResult struct {
	Found       []resources.Supply `json:"found"`
	ScoutLevel  int                `json:"scout_level"` // level used for the roll
	RollResult  int                `json:"roll_result"`
	Description string             `json:"description"`
}

// Scavenge performs a scavenging check and returns found supplies.
// scoutLevel: the character's scouting stat. Higher = more finds.
func Scavenge(scoutLevel int) ScavengeResult {
	all := resources.Supplies()
	roll := rand.Intn(20) + 1
	total := roll + scoutLevel

	// Filter by rarity: higher roll = access to rarer items.
	var eligible []resources.Supply
	for _, s := range all {
		if s.Rarity <= (total/4)+1 {
			eligible = append(eligible, s)
		}
	}
	if len(eligible) == 0 {
		eligible = all[:3] // always find something basic
	}

	// Number of items found scales with total roll.
	count := 1
	if total >= 15 {
		count = 3
	} else if total >= 10 {
		count = 2
	}

	if count > len(eligible) {
		count = len(eligible)
	}

	// Shuffle and take first N.
	rand.Shuffle(len(eligible), func(i, j int) { eligible[i], eligible[j] = eligible[j], eligible[i] })
	found := eligible[:count]

	desc := "You poke through the rubble and find a few things."
	if total >= 18 {
		desc = "Jackpot. This spot was untouched."
	} else if total >= 12 {
		desc = "Not bad. Someone was here before you, but left some things behind."
	} else if total < 6 {
		desc = "Barely anything. Either someone beat you to it or there was never much here."
	}

	return ScavengeResult{
		Found:       found,
		ScoutLevel:  scoutLevel,
		RollResult:  total,
		Description: desc,
	}
}
