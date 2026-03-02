// Package character defines the Character data model, generator, and SQLite persistence.
package character

import "time"

// CharacterStats holds the seven core skills for an M20 character.
type CharacterStats struct {
	Strength     int `json:"strength"`
	Stamina      int `json:"stamina"`
	Marksmanship int `json:"marksmanship"`
	Scouting     int `json:"scouting"`
	Scavenging   int `json:"scavenging"`
	Crafting     int `json:"crafting"`
	Salvaging    int `json:"salvaging"`
}

// Character is the full persistent representation of a player character.
type Character struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Class     string         `json:"class"`
	Level     int            `json:"level"`
	XP        int            `json:"xp"`
	HP        int            `json:"hp"`
	MaxHP     int            `json:"max_hp"`
	Stats     CharacterStats `json:"stats"`
	Inventory []string       `json:"inventory"` // item names
	Location  string         `json:"location"`  // current tile ID
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
}

// XPForNextLevel returns the XP threshold for levelling up.
func XPForNextLevel(level int) int {
	return level * 100
}

// IsReadyToLevelUp returns true if the character has enough XP to advance.
func (c *Character) IsReadyToLevelUp() bool {
	return c.XP >= XPForNextLevel(c.Level)
}

// LevelUp advances the character and resets XP.
func (c *Character) LevelUp() {
	c.XP -= XPForNextLevel(c.Level)
	c.Level++
	c.MaxHP += 2
	c.HP = c.MaxHP
}

// MaxInventorySlots returns the number of inventory slots (Hoarder gets +3).
func (c *Character) MaxInventorySlots() int {
	if c.Class == "Hoarder" {
		return 8
	}
	return 5
}
