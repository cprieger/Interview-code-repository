package weather

import (
	"context"
	"testing"
)

func TestGetWeather_CacheHit(t *testing.T) {
	client := NewClient()
	location := "lubbock"
	ctx := context.Background()

	// Prime the cache
	mockData := WeatherData{Temperature: 72.5, Conditions: "Sunny"}
	client.cache.Store(location, mockData)

	// Should return cached data
	data, err := client.GetWeather(ctx, location)
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if data == nil {
		t.Fatal("Expected data, got nil")
	}
	if data.Temperature != 72.5 {
		t.Errorf("Expected temperature 72.5, got %f", data.Temperature)
	}
	if data.Conditions != "Sunny" {
		t.Errorf("Expected conditions 'Sunny', got '%s'", data.Conditions)
	}
}

func TestGetWeather_CacheMiss(t *testing.T) {
	client := NewClient()
	location := "austin"
	ctx := context.Background()

	// Cache should be empty, should create new data
	data, err := client.GetWeather(ctx, location)
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if data == nil {
		t.Fatal("Expected data, got nil")
	}
	if data.Temperature != 72.0 {
		t.Errorf("Expected default temperature 72.0, got %f", data.Temperature)
	}
	if data.Conditions != "Sunny" {
		t.Errorf("Expected default conditions 'Sunny', got '%s'", data.Conditions)
	}

	// Verify it was cached
	cachedData, err := client.GetWeather(ctx, location)
	if err != nil {
		t.Fatalf("Expected no error on second call, got: %v", err)
	}
	if cachedData.Temperature != 72.0 {
		t.Errorf("Expected cached temperature 72.0, got %f", cachedData.Temperature)
	}
}

func TestGetWeather_ChaosPriority(t *testing.T) {
	client := NewClient()
	location := "lubbock"
	ctx := context.Background()

	// 1. Prime the Cache (Simulate a successful previous request)
	mockData := WeatherData{Temperature: 72.5, Conditions: "Sunny"}
	client.cache.Store(location, mockData)

	// 2. Test Case: Normal Request (Should return Cached 200)
	data, err := client.GetWeather(ctx, location)
	if err != nil {
		t.Fatalf("Normal request failed: %v", err)
	}
	if data == nil {
		t.Fatal("Expected cached data, got nil")
	}

	// 3. Test Case: Chaos Request (Should bypass Cache and return 500)
	// Use the correct context key: "chaos_trigger"
	chaosCtx := context.WithValue(ctx, "chaos_trigger", "true")

	_, err = client.GetWeather(chaosCtx, location)
	if err == nil {
		t.Fatal("Expected error when chaos trigger is set, got nil")
	}

	expectedErr := "simulated_upstream_failure_500"
	if err.Error() != expectedErr {
		t.Errorf("Expected error '%s', got '%s'", expectedErr, err.Error())
	}
}

func TestGetWeather_ChaosWithCacheMiss(t *testing.T) {
	client := NewClient()
	location := "dallas"
	ctx := context.Background()

	// Chaos should trigger even if cache is empty
	chaosCtx := context.WithValue(ctx, "chaos_trigger", "true")

	_, err := client.GetWeather(chaosCtx, location)
	if err == nil {
		t.Fatal("Expected error when chaos trigger is set, got nil")
	}

	expectedErr := "simulated_upstream_failure_500"
	if err.Error() != expectedErr {
		t.Errorf("Expected error '%s', got '%s'", expectedErr, err.Error())
	}
}

func TestGetWeather_ChaosFalse(t *testing.T) {
	client := NewClient()
	location := "houston"
	ctx := context.Background()

	// Setting chaos_trigger to "false" should not trigger chaos
	ctx = context.WithValue(ctx, "chaos_trigger", "false")

	data, err := client.GetWeather(ctx, location)
	if err != nil {
		t.Fatalf("Expected no error when chaos is false, got: %v", err)
	}
	if data == nil {
		t.Fatal("Expected data, got nil")
	}
}
