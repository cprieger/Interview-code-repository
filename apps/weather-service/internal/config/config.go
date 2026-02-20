package config

import (
	"os"
	"time"
)

type Config struct {
	Port           string
	WeatherAPIKey  string
	LogLevel       string
	CacheTTL       time.Duration
	RequestTimeout time.Duration
}

// Load populates the configuration from environment variables with sensible defaults
func Load() *Config {
	return &Config{
		Port:           getEnv("PORT", "8080"),
		WeatherAPIKey:  getEnv("WEATHER_API_KEY", "mock-key"), //
		LogLevel:       getEnv("LOG_LEVEL", "info"),
		CacheTTL:       5 * time.Minute,
		RequestTimeout: 10 * time.Second,
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}
