package weather

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"weather-service/internal/obs"
)

type WeatherData struct {
	Temperature float64 `json:"temperature"`
	Conditions  string  `json:"conditions"`
	Humidity    float64 `json:"humidity"`
	WindSpeed   float64 `json:"wind_speed"`
	Cached      bool    `json:"cached"`
}

type Client struct {
	httpClient *http.Client
	cache      sync.Map
}

func NewClient() *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

func (c *Client) GetWeather(ctx context.Context, location string) (*WeatherData, error) {
	// 1. Chaos Injection: Triggered by context from the middleware/handler
	if ctx.Value("chaos_trigger") == "true" {
		slog.Warn("Chaos mode active: injecting failure", "trace_id", ctx.Value("trace_id"))
		return nil, fmt.Errorf("simulated downstream failure")
	}

	// 2. Cache-Aside Pattern
	if val, ok := c.cache.Load(location); ok {
		data := val.(WeatherData)
		data.Cached = true
		obs.CacheHits.Inc()
		return &data, nil
	}

	obs.CacheMisses.Inc()
	var data WeatherData

	// 3. Resilience: Retry with Exponential Backoff
	err := c.retry(ctx, 3, 500*time.Millisecond, func() error {
		// Public API - Open-Meteo (No Key Required)
		// Coordinates for Lubbock, TX used as the example fetch
		url := "https://api.open-meteo.com/v1/forecast?latitude=33.57&longitude=-101.85&current=temperature_2m,relative_humidity_2m,wind_speed_10m"

		req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
		if err != nil {
			return err
		}

		resp, err := c.httpClient.Do(req)
		if err != nil {
			return err
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			return fmt.Errorf("upstream api returned status: %d", resp.StatusCode)
		}

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return err
		}

		// Internal anonymous struct to map the specific Open-Meteo response
		var result struct {
			Current struct {
				Temp     float64 `json:"temperature_2m"`
				Humidity float64 `json:"relative_humidity_2m"`
				Wind     float64 `json:"wind_speed_10m"`
			} `json:"current"`
		}

		if err := json.Unmarshal(body, &result); err != nil {
			return err
		}

		data = WeatherData{
			Temperature: result.Current.Temp,
			Conditions:  "Clear/Sunny (Mocked)",
			Humidity:    result.Current.Humidity,
			WindSpeed:   result.Current.Wind,
			Cached:      false,
		}
		return nil
	})

	if err != nil {
		return nil, err
	}

	// 4. Update Cache for subsequent requests
	c.cache.Store(location, data)
	return &data, nil
}

// retry handles the exponential backoff logic
func (c *Client) retry(ctx context.Context, attempts int, sleep time.Duration, f func() error) error {
	for i := 0; i < attempts; i++ {
		if err := f(); err == nil {
			return nil
		}

		slog.Warn("retrying upstream request", "attempt", i+1, "trace_id", ctx.Value("trace_id"))

		select {
		case <-time.After(sleep):
			sleep *= 2
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	return fmt.Errorf("request failed after %d attempts", attempts)
}
