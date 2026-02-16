package weather

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"weather-service/internal/obs"
)

type ctxKey string

const ChaosTriggerKey ctxKey = "chaos_trigger"

type WeatherData struct {
	Temperature float64 `json:"temperature"`
	Conditions  string  `json:"conditions"`
}

type Client struct {
	cache sync.Map
}

func NewClient() *Client {
	return &Client{}
}

func (c *Client) GetWeather(ctx context.Context, location string) (*WeatherData, error) {
	// 1. CHAOS CHECK MUST BE FIRST
	val, _ := ctx.Value(ChaosTriggerKey).(string)

	if val == "true" {
		slog.Error("ENGINE: CHAOS TRIGGERED - BYPASSING CACHE")
		return nil, fmt.Errorf("chaos_active")
	}

	// 2. CACHE CHECK
	if cached, ok := c.cache.Load(location); ok {
		slog.Debug("ENGINE: CACHE HIT")
		data := cached.(WeatherData)
		return &data, nil
	}

	// 3. MOCK DATA
	obs.CacheMisses.Inc()
	data := WeatherData{Temperature: 75, Conditions: "Sunny"}
	c.cache.Store(location, data)
	return &data, nil
}
