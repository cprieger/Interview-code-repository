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

// Equipment holds the three item slots a character can have equipped.
type Equipment struct {
	Weapon    string `json:"weapon"`    // item name or ""
	Armor     string `json:"armor"`     // item name or ""
	Accessory string `json:"accessory"` // item name or ""
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
	Inventory []string       `json:"inventory"`  // item names
	Equipment Equipment      `json:"equipment"`   // equipped items (3 slots)
	Location  string         `json:"location"`   // current tile ID
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
// +4 MaxHP per level (aligned with client-side logic).
func (c *Character) LevelUp() {
	c.XP -= XPForNextLevel(c.Level)
	c.Level++
	c.MaxHP += 4
	c.HP = c.MaxHP
}

// MaxInventorySlots returns the number of inventory slots.
// Hoarder class gets 25 slots; everyone else gets 20.
func (c *Character) MaxInventorySlots() int {
	if c.Class == "Hoarder" {
		return 25
	}
	return 20
}

// RemoveFirstItem removes the first occurrence of itemName from Inventory.
// Returns true if the item was found and removed, false otherwise.
func (c *Character) RemoveFirstItem(itemName string) bool {
	for i, name := range c.Inventory {
		if name == itemName {
			c.Inventory = append(c.Inventory[:i], c.Inventory[i+1:]...)
			return true
		}
	}
	return false
}

// ContainsItem returns true if the inventory has at least one of itemName.
func (c *Character) ContainsItem(itemName string) bool {
	for _, name := range c.Inventory {
		if name == itemName {
			return true
		}
	}
	return false
}
