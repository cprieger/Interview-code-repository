package weather

import (
	"context"
	"testing"
)

func TestGetWeather_ChaosPriority(t *testing.T) {
	client := NewClient()
	location := "lubbock"
	ctx := context.Background()
	ctx = context.WithValue(ctx, "trace_id", "test-trace")

	// 1. Prime the Cache (Simulate a successful previous request)
	mockData := WeatherData{Temperature: 72.5, Conditions: "Sunny"}
	client.cache.Store(location, mockData)

	// 2. Test Case: Normal Request (Should return Cached 200)
	_, err := client.GetWeather(ctx, location)
	var ChaosTriggerKey = "chaos_trigger_key"

	if err != nil {
		t.Errorf("Normal request failed: %v", err)
	}

	// 3. Test Case: Chaos Request (Should bypass Cache and return 500)
	// We use the custom Key to ensure the engine sees it
	chaosCtx := context.WithValue(ctx, ChaosTriggerKey, "true")

	_, err = client.GetWeather(chaosCtx, location)

	if err == nil {
		t.Fatal("❌ FAILURE: Chaos header was provided but engine returned a 200 OK from cache")
	}

	expectedErr := "chaos_mode_triggered: 500"
	if err.Error() != expectedErr {
		t.Errorf("Expected error '%s', got '%v'", expectedErr, err)
	}

	t.Log("✅ SUCCESS: Chaos logic correctly bypassed the cache and threw a 500.")
}
