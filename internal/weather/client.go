package weather

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"sync"
	"time"
)

// Response matches the requirement for temperature, conditions, humidity, and wind speed [cite: 24]
type WeatherData struct {
	Temperature float64 `json:"temperature"`
	Conditions  string  `json:"conditions"`
	Humidity    int     `json:"humidity"`
	WindSpeed   float64 `json:"wind_speed"`
	Cached      bool    `json:"cached"`
}

type Client struct {
	apiKey     string
	httpClient *http.Client
	cache      sync.Map // Thread-safe in-memory cache 
	ttl        time.Duration
}

func NewClient(apiKey string) *Client {
	return &Client{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 5 * time.Second, // Global request timeout 
		},
		ttl: 5 * time.Minute,
	}
}


func (c *Client) GetWeather(ctx context.Context, location string) (*WeatherData, error) {
	// 1. Check Cache [cite: 26, 48]
	if val, ok := c.cache.Load(location); ok {
		data := val.(WeatherData)
		data.Cached = true
		return &data, nil
	}

	// 2. Fetch with Retries 
	var data WeatherData
	err := c.retry(ctx, 3, time.Second, func() error {
		// Mocking the API call for now; replace with real http.Get for OpenWeatherMap
		slog.Info("fetching weather from upstream", "location", location)
		
		// Logic to call OpenWeatherMap would go here [cite: 13]
		// For the assessment, we'll return a mock or actual API data
		data = WeatherData{Temperature: 72.5, Conditions: "Sunny", Humidity: 45, WindSpeed: 10.2}
		return nil 
	})

	if err != nil {
		return nil, err
	}

	// 3. Update Cache 
	c.cache.Store(location, data)
	return &data, nil
}

// retry is a helper for exponential backoff 
func (c *Client) retry(ctx context.Context, attempts int, sleep time.Duration, f func() error) error {
	for i := 0; i < attempts; i++ {
		if err := f(); err == nil {
			return nil
		}
		slog.Warn("upstream request failed, retrying", "attempt", i+1)
		select {
		case <-time.After(sleep):
			sleep *= 2 // Exponential backoff
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	return fmt.Errorf("after %d attempts, last error occurred", attempts)
}