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

// Use a simple string constant for the key to ensure zero casting errors
const ChaosTriggerKey = "chaos_trigger"

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
	// 1. HARD LOG: Show us exactly what is in the context
	chaosVal, _ := ctx.Value(ChaosTriggerKey).(string)
	traceID, _ := ctx.Value("trace_id").(string)

	slog.Info("Engine executing request",
		"location", location,
		"chaos_detected", chaosVal,
		"trace_id", traceID,
	)

	// 2. PRIORITY: CHAOS CHECK
	if chaosVal == "true" {
		slog.Error("!!! FAULT INJECTION FIRING !!!", "trace_id", traceID)
		return nil, fmt.Errorf("chaos_mode_triggered: simulated 500 error")
	}

	// 3. CACHE CHECK
	if val, ok := c.cache.Load(location); ok {
		data := val.(WeatherData)
		data.Cached = true
		obs.CacheHits.Inc()
		return &data, nil
	}

	obs.CacheMisses.Inc()
	// ... rest of fetch logic ...
	return c.fetchFromAPI(ctx, location)
}

// Separated for clarity
func (c *Client) fetchFromAPI(ctx context.Context, location string) (*WeatherData, error) {
	url := "https://api.open-meteo.com/v1/forecast?latitude=33.57&longitude=-101.85&current=temperature_2m,relative_humidity_2m,wind_speed_10m"
	req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result struct {
		Current struct {
			Temp float64 `json:"temperature_2m"`
		} `json:"current"`
	}
	body, _ := io.ReadAll(resp.Body)
	json.Unmarshal(body, &result)

	data := WeatherData{Temperature: result.Current.Temp, Conditions: "Operational"}
	c.cache.Store(location, data)
	return &data, nil
}
