package weather

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestGetWeather_Caching(t *testing.T) {
	client := NewClient()
	location := "lubbock"

	// Mock data
	data := WeatherData{Temperature: 20.0, Conditions: "Test"}

	// Manually prime the cache
	client.cache.Store(location, data)

	// First call should be cached
	res, err := client.GetWeather(context.Background(), location)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if !res.Cached {
		t.Errorf("expected data to be marked as cached")
	}
}

func TestRetryLogic(t *testing.T) {
	attempts := 0
	// Setup a mock server that fails twice then succeeds
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		if attempts < 3 {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"current":{"temperature_2m":70,"relative_humidity_2m":40,"wind_speed_10m":10}}`))
	}))
	defer server.Close()

	client := NewClient()
	
	// We wrap the function to test the retry mechanism specifically
	err := client.retry(context.Background(), 3, 1*time.Millisecond, func() error {
		resp, err := http.Get(server.URL)
		if err != nil {
			return err
		}
		if resp.StatusCode != http.StatusOK {
			return http.ErrHandlerTimeout
		}
		return nil
	})

	if err != nil {
		t.Errorf("expected eventual success, got error: %v", err)
	}

	if attempts != 3 {
		t.Errorf("expected 3 attempts, got %d", attempts)
	}
}