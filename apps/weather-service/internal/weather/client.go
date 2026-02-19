package weather

import (
	"context"
	"fmt"
	"sync"
)

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
	// CHECK CONTEXT FOR CHAOS
	if val, _ := ctx.Value("chaos_trigger").(string); val == "true" {
		return nil, fmt.Errorf("simulated_upstream_failure_500")
	}

	// Normal Cache Logic
	if val, ok := c.cache.Load(location); ok {
		data := val.(WeatherData)
		return &data, nil
	}

	data := WeatherData{Temperature: 72.0, Conditions: "Sunny"}
	c.cache.Store(location, data)
	return &data, nil
}
