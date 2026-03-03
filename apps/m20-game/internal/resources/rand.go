package resources

import "math/rand"

// randN returns a random int in [0, n). Panics if n <= 0.
func randN(n int) int {
	if n <= 0 {
		return 0
	}
	return rand.Intn(n)
}
