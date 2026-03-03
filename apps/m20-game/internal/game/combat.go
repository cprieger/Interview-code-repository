// Package game implements the M20 core rules: D20 roll engine, tile generation,
// monster encounters, scavenging, building exploration, and map generation.
package game

import (
	"math/rand"

	"m20-game/internal/obs"
)

// RollOutcome classifies a D20 combat roll.
type RollOutcome string

const (
	OutcomeCritSuccess RollOutcome = "crit_success" // natural 20
	OutcomeSuccess     RollOutcome = "success"
	OutcomeFailure     RollOutcome = "failure"
	OutcomeCritFailure RollOutcome = "crit_failure" // natural 1
)

// CombatRollRequest is the input to a combat roll.
type CombatRollRequest struct {
	StatValue int `json:"stat"`  // the relevant character stat
	Bonus     int `json:"bonus"` // situational or class bonus
}

// CombatRollResult is the full result of a D20 roll.
type CombatRollResult struct {
	Roll       int         `json:"roll"`        // raw D20 result (1-20)
	Total      int         `json:"total"`        // roll + stat + bonus
	Outcome    RollOutcome `json:"outcome"`
	StatValue  int         `json:"stat_value"`
	Bonus      int         `json:"bonus"`
	CritThresh int         `json:"crit_threshold"` // roll >= this = crit success
}

// Roll executes a D20 combat check.
// Critical success: natural 20. Critical failure: natural 1.
// The critThreshold parameter lets class abilities lower the crit threshold.
func Roll(req CombatRollRequest, critThreshold int) CombatRollResult {
	if critThreshold <= 0 {
		critThreshold = 20
	}

	roll := rand.Intn(20) + 1
	total := roll + req.StatValue + req.Bonus

	var outcome RollOutcome
	switch {
	case roll == 1:
		outcome = OutcomeCritFailure
	case roll >= critThreshold:
		outcome = OutcomeCritSuccess
	case total >= 10:
		outcome = OutcomeSuccess
	default:
		outcome = OutcomeFailure
	}

	obs.CombatRollsTotal.WithLabelValues(string(outcome)).Inc()

	return CombatRollResult{
		Roll:       roll,
		Total:      total,
		Outcome:    outcome,
		StatValue:  req.StatValue,
		Bonus:      req.Bonus,
		CritThresh: critThreshold,
	}
}

// D20 returns a raw 1-20 roll with no modifiers.
func D20() int {
	return rand.Intn(20) + 1
}
