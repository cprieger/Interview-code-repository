// Package config loads environment variables with safe defaults.
package config

import "os"

// Config holds all runtime configuration for m20-game.
type Config struct {
	Port      string
	DBPath    string
	OllamaURL string
	LogLevel  string
}

// Load reads environment variables and returns a Config with defaults applied.
func Load() *Config {
	return &Config{
		Port:      getEnv("PORT", "8082"),
		DBPath:    getEnv("DB_PATH", "./data/m20.db"),
		OllamaURL: getEnv("OLLAMA_URL", "http://ollama:11434"),
		LogLevel:  getEnv("LOG_LEVEL", "info"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
