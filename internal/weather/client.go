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
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}
}

func (c *Client) GetWeather(ctx context.Context, location string) (*WeatherData, error) {
	// 1. Check Cache [cite: 14, 48]
	if val, ok := c.cache.Load(location); ok {
		data := val.(WeatherData)
		data.Cached = true
		obs.CacheHits.Inc()
		return &data, nil
	}

	obs.CacheMisses.Inc()
	var data WeatherData

	// 2. Fetch with Retries (Exponential Backoff) [cite: 16, 46]
	err := c.retry(ctx, 3, 500*time.Millisecond, func() error {
		// Public API: No Key Required. Hardcoded to Lubbock, TX coordinates for this example.
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
			return fmt.Errorf("upstream api error: %d", resp.StatusCode)
		}

		body, _ := io.ReadAll(resp.Body)
		
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
			Conditions:  "Live Data (Open-Meteo)",
			Humidity:    result.Current.Humidity,
			WindSpeed:   result.Current.Wind,
			Cached:      false,
		}
		return nil
	})

	if err != nil {
		return nil, err
	}

	// 3. Store in cache [cite: 14, 48]
	c.cache.Store(location, data)
	return &data, nil
}

func (c *Client) retry(ctx context.Context, attempts int, sleep time.Duration, f func() error) error {
	for i := 0; i < attempts; i++ {
		if err := f(); err == nil {
			return nil
		}
		slog.Warn("retrying upstream call", "attempt", i+1)
		select {
		case <-time.After(sleep):
			sleep *= 2
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	return fmt.Errorf("failed after %d attempts", attempts)
}