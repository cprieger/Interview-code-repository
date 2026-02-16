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

// Private type for context keys to prevent collisions
type ctxKey string

const ChaosTriggerKey ctxKey = "chaos_trigger"

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
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}
}

func (c *Client) GetWeather(ctx context.Context, location string) (*WeatherData, error) {
	traceID, _ := ctx.Value("trace_id").(string)

	// --- 1. PRIORITY: CHAOS CHECK ---
	if val, ok := ctx.Value(ChaosTriggerKey).(string); ok && val == "true" {
		slog.Error("!!! FAULT INJECTION ACTIVE: BYPASSING CACHE !!!",
			slog.String("trace_id", traceID),
			slog.String("location", location),
		)
		return nil, fmt.Errorf("chaos_mode_triggered: 500")
	}

	// --- 2. CACHE CHECK ---
	if val, ok := c.cache.Load(location); ok {
		data := val.(WeatherData)
		data.Cached = true
		obs.CacheHits.Inc()
		return &data, nil
	}

	obs.CacheMisses.Inc()
	var data WeatherData

	// --- 3. FETCH ---
	err := c.retry(ctx, 3, 500*time.Millisecond, func() error {
		// Public API - Open-Meteo
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
			return fmt.Errorf("upstream error: %d", resp.StatusCode)
		}

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return err
		}

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
			Conditions:  "Operational",
			Humidity:    result.Current.Humidity,
			WindSpeed:   result.Current.Wind,
			Cached:      false,
		}
		return nil
	})

	if err != nil {
		return nil, err
	}

	c.cache.Store(location, data)
	return &data, nil
}

func (c *Client) retry(ctx context.Context, attempts int, sleep time.Duration, f func() error) error {
	for i := 0; i < attempts; i++ {
		if err := f(); err == nil {
			return nil
		}
		select {
		case <-time.After(sleep):
			sleep *= 2
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	return fmt.Errorf("max retries reached")
}
