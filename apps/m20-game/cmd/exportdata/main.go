// Command exportdata marshals every static M20 resource table to JSON so the
// Godot voxel client (apps/m20-voxel) can consume canon without transcription.
//
// The Go tables in internal/resources are the single source of truth. Two
// hand-maintained copies of the same data drift within a week; this tool makes
// drift impossible. If canon changes, change it in Go and re-run.
//
// Usage:
//
//	go run ./cmd/exportdata                      # writes ../m20-voxel/data
//	go run ./cmd/exportdata -out ./export        # custom destination
//	go run ./cmd/exportdata -check               # verify output is current (CI)
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"time"

	"m20-game/internal/resources"
)

// groupedLocations are every key in the monster-group table: the six real
// buildings plus five lair-style locations that have groups but no Building entry.
var groupedLocations = []string{
	"Hospital",
	"Pharmacy",
	"Hardware Store",
	"Police Station",
	"School",
	"Auto Repair Shop",
	"Supermarket",
	"Sphinx Chamber",
	"Windego Den",
	"Vampire Nest",
	"Werewolf Pack",
	"Basilisk Lair",
}

// manifest records what was exported and a digest of each payload, so the Godot
// side can detect stale data and CI can verify the checked-in export is current.
type manifest struct {
	GeneratedAt time.Time         `json:"generated_at"`
	Source      string            `json:"source"`
	Files       map[string]string `json:"files"` // filename -> sha256
}

func main() {
	out := flag.String("out", filepath.Join("..", "m20-voxel", "data"), "destination directory")
	check := flag.Bool("check", false, "verify existing output matches current canon; exit 1 if stale")
	flag.Parse()

	tables := collect()

	if *check {
		if err := verify(*out, tables); err != nil {
			fmt.Fprintf(os.Stderr, "exportdata: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("exportdata: canon export is current")
		return
	}

	if err := write(*out, tables); err != nil {
		fmt.Fprintf(os.Stderr, "exportdata: %v\n", err)
		os.Exit(1)
	}
}

// collect gathers every table we export, keyed by output filename.
func collect() map[string]any {
	groups := make(map[string][]resources.MonsterGroup, len(groupedLocations))
	for _, loc := range groupedLocations {
		if g := resources.GroupsForBuilding(loc); len(g) > 0 {
			groups[loc] = g
		}
	}

	return map[string]any{
		"classes.json":        resources.Classes(),
		"monsters.json":       resources.Monsters(),
		"monster_groups.json": groups,
		"tiles.json":          resources.Tiles(),
		"buildings.json":      resources.Buildings(),
		"supplies.json":       resources.Supplies(),
		"craftables.json":     resources.CraftableItems(),
		"vehicles.json":       resources.Vehicles(),
		"equip_bonuses.json":  resources.EquipBonuses,
		"equip_slots.json":    resources.EquipSlots(),
	}
}

// encode produces stable, human-diffable JSON. Stability matters: an unstable
// encoder turns every re-export into a noisy diff and hides real changes.
func encode(v any) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func digest(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

func write(dir string, tables map[string]any) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("create %s: %w", dir, err)
	}

	m := manifest{
		GeneratedAt: time.Now().UTC(),
		Source:      "apps/m20-game/internal/resources (via cmd/exportdata)",
		Files:       make(map[string]string, len(tables)),
	}

	for _, name := range sortedKeys(tables) {
		data, err := encode(tables[name])
		if err != nil {
			return fmt.Errorf("encode %s: %w", name, err)
		}
		if err := os.WriteFile(filepath.Join(dir, name), data, 0o644); err != nil {
			return fmt.Errorf("write %s: %w", name, err)
		}
		m.Files[name] = digest(data)
		fmt.Printf("  %-22s %6d bytes\n", name, len(data))
	}

	mdata, err := encode(m)
	if err != nil {
		return fmt.Errorf("encode manifest: %w", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "manifest.json"), mdata, 0o644); err != nil {
		return fmt.Errorf("write manifest: %w", err)
	}

	fmt.Printf("\nexportdata: wrote %d tables + manifest to %s\n", len(tables), dir)
	return nil
}

// verify re-encodes canon and compares digests against what's on disk. Used in
// CI so a change to internal/resources can't silently desync the Godot client.
func verify(dir string, tables map[string]any) error {
	for _, name := range sortedKeys(tables) {
		want, err := encode(tables[name])
		if err != nil {
			return fmt.Errorf("encode %s: %w", name, err)
		}
		got, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			return fmt.Errorf("%s missing or unreadable — run `go run ./cmd/exportdata`: %w", name, err)
		}
		if !bytes.Equal(want, got) {
			return fmt.Errorf("%s is stale — run `go run ./cmd/exportdata`", name)
		}
	}
	return nil
}

func sortedKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
