package game

import (
	"math/rand"

	"m20-game/internal/resources"
)

// VehicleFindResult is the outcome of discovering a vehicle.
type VehicleFindResult struct {
	Vehicle     resources.Vehicle `json:"vehicle"`
	NeedsRepair bool              `json:"needs_repair"`
	Description string            `json:"description"`
}

// FindVehicle discovers a random vehicle in the world.
func FindVehicle() VehicleFindResult {
	vehicles := resources.Vehicles()
	v := vehicles[rand.Intn(len(vehicles))]

	needsRepair := v.Condition == "damaged" || v.Condition == "wreck"
	desc := "You find a " + v.Name + ". " + v.Description
	if needsRepair {
		desc += " It needs work before it goes anywhere."
	} else {
		desc += " Runs well enough."
	}

	return VehicleFindResult{
		Vehicle:     v,
		NeedsRepair: needsRepair,
		Description: desc,
	}
}
