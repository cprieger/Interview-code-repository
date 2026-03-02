package character

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	_ "modernc.org/sqlite" // pure-Go SQLite driver, no CGO required
)

// Store persists characters to SQLite.
// The interface is designed for easy swap to PostgreSQL in production.
type Store struct {
	db *sql.DB
}

// NewStore opens (or creates) a SQLite database at the given path.
func NewStore(dbPath string) (*Store, error) {
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}

	// Enable WAL mode for better concurrent read performance.
	if _, err := db.Exec("PRAGMA journal_mode=WAL"); err != nil {
		return nil, fmt.Errorf("enable WAL: %w", err)
	}

	if err := migrate(db); err != nil {
		return nil, fmt.Errorf("migrate: %w", err)
	}

	return &Store{db: db}, nil
}

// migrate creates the schema if it does not exist.
func migrate(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS characters (
			id          TEXT PRIMARY KEY,
			name        TEXT NOT NULL,
			class       TEXT NOT NULL,
			level       INTEGER NOT NULL DEFAULT 1,
			xp          INTEGER NOT NULL DEFAULT 0,
			hp          INTEGER NOT NULL,
			max_hp      INTEGER NOT NULL,
			stats_json  TEXT NOT NULL,
			inv_json    TEXT NOT NULL DEFAULT '[]',
			location    TEXT NOT NULL DEFAULT 'tile-01',
			created_at  DATETIME NOT NULL,
			updated_at  DATETIME NOT NULL
		)
	`)
	return err
}

// Save creates or updates a character.
func (s *Store) Save(ctx context.Context, c *Character) error {
	statsJSON, err := json.Marshal(c.Stats)
	if err != nil {
		return fmt.Errorf("marshal stats: %w", err)
	}
	invJSON, err := json.Marshal(c.Inventory)
	if err != nil {
		return fmt.Errorf("marshal inventory: %w", err)
	}

	c.UpdatedAt = time.Now().UTC()

	_, err = s.db.ExecContext(ctx, `
		INSERT INTO characters (id, name, class, level, xp, hp, max_hp, stats_json, inv_json, location, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			name=excluded.name, class=excluded.class, level=excluded.level,
			xp=excluded.xp, hp=excluded.hp, max_hp=excluded.max_hp,
			stats_json=excluded.stats_json, inv_json=excluded.inv_json,
			location=excluded.location, updated_at=excluded.updated_at
	`,
		c.ID, c.Name, c.Class, c.Level, c.XP, c.HP, c.MaxHP,
		string(statsJSON), string(invJSON), c.Location,
		c.CreatedAt, c.UpdatedAt,
	)
	return err
}

// Load retrieves a character by ID.
// Returns (nil, nil) if not found.
func (s *Store) Load(ctx context.Context, id string) (*Character, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT id, name, class, level, xp, hp, max_hp, stats_json, inv_json, location, created_at, updated_at
		FROM characters WHERE id = ?
	`, id)

	var c Character
	var statsJSON, invJSON string
	var createdAt, updatedAt string

	err := row.Scan(
		&c.ID, &c.Name, &c.Class, &c.Level, &c.XP, &c.HP, &c.MaxHP,
		&statsJSON, &invJSON, &c.Location, &createdAt, &updatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("scan character: %w", err)
	}

	if err := json.Unmarshal([]byte(statsJSON), &c.Stats); err != nil {
		return nil, fmt.Errorf("unmarshal stats: %w", err)
	}
	if err := json.Unmarshal([]byte(invJSON), &c.Inventory); err != nil {
		return nil, fmt.Errorf("unmarshal inventory: %w", err)
	}

	c.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	c.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)

	return &c, nil
}

// Close shuts down the database connection.
func (s *Store) Close() error {
	return s.db.Close()
}
