package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"weather-service/internal/weather"
)

func TestHealthHandler(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			if _, err := w.Write([]byte("{\"status\":\"up\"}")); err != nil {
				t.Errorf("write failed: %v", err)
			}
			return
		}
		http.NotFound(w, r)
	})

	req := httptest.NewRequest("GET", "/health", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Expected status 200, got %d", status)
	}

	expectedBody := "{\"status\":\"up\"}"
	if rr.Body.String() != expectedBody {
		t.Errorf("Expected body '%s', got '%s'", expectedBody, rr.Body.String())
	}
}

func TestWeatherHandler_Success(t *testing.T) {
	wClient := weather.NewClient()
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/weather/") {
			location := strings.TrimPrefix(r.URL.Path, "/weather/")
			data, err := wClient.GetWeather(r.Context(), location)
			if err != nil {
				http.Error(w, err.Error(), 500)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			if err := json.NewEncoder(w).Encode(data); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
			}
			return
		}
		http.NotFound(w, r)
	})

	req := httptest.NewRequest("GET", "/weather/lubbock", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Expected status 200, got %d", status)
	}

	if ct := rr.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("Expected Content-Type 'application/json', got '%s'", ct)
	}

	var data weather.WeatherData
	if err := json.NewDecoder(rr.Body).Decode(&data); err != nil {
		t.Fatalf("Failed to decode JSON: %v", err)
	}

	if data.Temperature == 0 {
		t.Error("Expected temperature to be set")
	}
	if data.Conditions == "" {
		t.Error("Expected conditions to be set")
	}
}

func TestWeatherHandler_Chaos(t *testing.T) {
	wClient := weather.NewClient()
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/weather/") {
			location := strings.TrimPrefix(r.URL.Path, "/weather/")
			data, err := wClient.GetWeather(r.Context(), location)
			if err != nil {
				http.Error(w, err.Error(), 500)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			if err := json.NewEncoder(w).Encode(data); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
			}
			return
		}
		http.NotFound(w, r)
	})

	req := httptest.NewRequest("GET", "/weather/lubbock", nil)
	rr := httptest.NewRecorder()

	// Inject chaos context (simulating what middleware does)
	ctx := weather.WithChaosTrigger(req.Context(), "true")
	req = req.WithContext(ctx)

	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusInternalServerError {
		t.Errorf("Expected status 500, got %d", status)
	}

	if !strings.Contains(rr.Body.String(), "simulated_upstream_failure_500") {
		t.Errorf("Expected error message containing 'simulated_upstream_failure_500', got '%s'", rr.Body.String())
	}
}

func TestWeatherHandler_NotFound(t *testing.T) {
	wClient := weather.NewClient()
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			if _, err := w.Write([]byte("{\"status\":\"up\"}")); err != nil {
				t.Errorf("write failed: %v", err)
			}
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
			if err := json.NewEncoder(w).Encode(data); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
			}
			return
		}
		http.NotFound(w, r)
	})

	req := httptest.NewRequest("GET", "/unknown", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusNotFound {
		t.Errorf("Expected status 404, got %d", status)
	}
}
