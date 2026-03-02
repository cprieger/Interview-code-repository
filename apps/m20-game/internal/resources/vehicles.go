package resources

// Vehicle is a transport option found in the world.
type Vehicle struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Speed       int    `json:"speed"`        // 1-10
	Capacity    int    `json:"capacity"`     // passengers
	Condition   string `json:"condition"`    // operational | damaged | wreck
	FuelNeeded  bool   `json:"fuel_needed"`
}

// Vehicles returns all discoverable vehicle types.
func Vehicles() []Vehicle {
	return []Vehicle{
		{
			Name:        "Pickup Truck",
			Description: "American ingenuity in sheet metal form. Plenty of cargo space.",
			Speed:       6,
			Capacity:    4,
			Condition:   "operational",
			FuelNeeded:  true,
		},
		{
			Name:        "Motorcycle",
			Description: "Fast. Loud. Zero protection. Perfect.",
			Speed:       9,
			Capacity:    2,
			Condition:   "operational",
			FuelNeeded:  true,
		},
		{
			Name:        "School Bus",
			Description: "Seats 40. Moves 8 of them per trip due to fuel consumption.",
			Speed:       4,
			Capacity:    20,
			Condition:   "damaged",
			FuelNeeded:  true,
		},
		{
			Name:        "Armored SUV",
			Description: "Someone prepared for this. Probably them.",
			Speed:       5,
			Capacity:    5,
			Condition:   "operational",
			FuelNeeded:  true,
		},
		{
			Name:        "Bicycle",
			Description: "Maintenance-free. Leg-powered. Surprisingly survivable.",
			Speed:       4,
			Capacity:    1,
			Condition:   "operational",
			FuelNeeded:  false,
		},
		{
			Name:        "Rusty Sedan",
			Description: "It runs. Barely. The transmission is optimistic.",
			Speed:       5,
			Capacity:    4,
			Condition:   "damaged",
			FuelNeeded:  true,
		},
	}
}
