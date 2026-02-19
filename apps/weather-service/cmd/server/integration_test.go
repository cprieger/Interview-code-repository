package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"weather-service/internal/weather"
)

// TestIntegration_WeatherEndpoint tests the full request flow:
// HTTP request -> middleware -> handler -> weather client
func TestIntegration_WeatherEndpoint(t *testing.T) {
	wClient := weather.NewClient()

	// Build the full handler chain
	apiHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/weather/") {
			location := strings.TrimPrefix(r.URL.Path, "/weather/")
			data, err := wClient.GetWeather(r.Context(), location)
			if err != nil {
				http.Error(w, err.Error(), 500)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(data)
			return
		}
		http.NotFound(w, r)
	})

	sreHandler := sreMiddleware(apiHandler)
	rootMux := http.NewServeMux()
	rootMux.Handle("/", sreHandler)

	// Test successful request
	req := httptest.NewRequest("GET", "/weather/lubbock", nil)
	rr := httptest.NewRecorder()
	rootMux.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Expected status 200, got %d", status)
	}

	var data weather.WeatherData
	if err := json.NewDecoder(rr.Body).Decode(&data); err != nil {
		t.Fatalf("Failed to decode JSON: %v", err)
	}

	if data.Temperature == 0 {
		t.Error("Expected temperature to be set")
	}
}

// TestIntegration_ChaosFlow tests the chaos injection flow end-to-end
func TestIntegration_ChaosFlow(t *testing.T) {
	wClient := weather.NewClient()

	apiHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/weather/") {
			location := strings.TrimPrefix(r.URL.Path, "/weather/")
			data, err := wClient.GetWeather(r.Context(), location)
			if err != nil {
				http.Error(w, err.Error(), 500)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(data)
			return
		}
		http.NotFound(w, r)
	})

	sreHandler := sreMiddleware(apiHandler)
	rootMux := http.NewServeMux()
	rootMux.Handle("/", sreHandler)

	// Test chaos via query param
	req := httptest.NewRequest("GET", "/weather/lubbock?chaos=true", nil)
	rr := httptest.NewRecorder()
	rootMux.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusInternalServerError {
		t.Errorf("Expected status 500, got %d", status)
	}

	if !strings.Contains(rr.Body.String(), "simulated_upstream_failure_500") {
		t.Errorf("Expected error message containing 'simulated_upstream_failure_500', got '%s'", rr.Body.String())
	}
}

// TestIntegration_HealthEndpoint tests the health check endpoint
func TestIntegration_HealthEndpoint(t *testing.T) {
	wClient := weather.NewClient()

	apiHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("{\"status\":\"up\"}"))
			return
		}
		if strings.HasPrefix(r.URL.Path, "/weather/") {
			location := strings.TrimPrefix(r.URL.Path, "/weather/")
			data, err := wClient.GetWeather(r.Context(), location)
			if err != nil {
				http.Error(w, err.Error(), 500)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(data)
			return
		}
		http.NotFound(w, r)
	})

	sreHandler := sreMiddleware(apiHandler)
	rootMux := http.NewServeMux()
	rootMux.Handle("/", sreHandler)

	req := httptest.NewRequest("GET", "/health", nil)
	rr := httptest.NewRecorder()
	rootMux.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Expected status 200, got %d", status)
	}

	expectedBody := "{\"status\":\"up\"}"
	if rr.Body.String() != expectedBody {
		t.Errorf("Expected body '%s', got '%s'", expectedBody, rr.Body.String())
	}
}

// TestIntegration_NotFound tests 404 handling
func TestIntegration_NotFound(t *testing.T) {
	wClient := weather.NewClient()

	apiHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("{\"status\":\"up\"}"))
			return
		}
		if strings.HasPrefix(r.URL.Path, "/weather/") {
			location := strings.TrimPrefix(r.URL.Path, "/weather/")
			data, err := wClient.GetWeather(r.Context(), location)
			if err != nil {
				http.Error(w, err.Error(), 500)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(data)
			return
		}
		http.NotFound(w, r)
	})

	sreHandler := sreMiddleware(apiHandler)
	rootMux := http.NewServeMux()
	rootMux.Handle("/", sreHandler)

	req := httptest.NewRequest("GET", "/unknown", nil)
	rr := httptest.NewRecorder()
	rootMux.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusNotFound {
		t.Errorf("Expected status 404, got %d", status)
	}
}
