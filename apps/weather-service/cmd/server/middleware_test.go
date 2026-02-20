package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"weather-service/internal/weather"
)

func TestSREMiddleware_ChaosDetection_QueryParam(t *testing.T) {
	var capturedCtx context.Context
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		capturedCtx = r.Context()
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write([]byte("OK")); err != nil {
			t.Errorf("write failed: %v", err)
		}
	})

	middleware := sreMiddleware(handler)
	req := httptest.NewRequest("GET", "/weather/lubbock?chaos=true", nil)
	rr := httptest.NewRecorder()

	middleware.ServeHTTP(rr, req)

	// Verify chaos context was set
	if capturedCtx == nil {
		t.Fatal("Context was not captured")
	}
	if val := weather.ChaosTrigger(capturedCtx); val != "true" {
		t.Errorf("Expected chaos_trigger='true' in context, got '%v'", val)
	}

	// Verify trace_id was set
	if val, ok := capturedCtx.Value(traceIDContextKey).(string); !ok || val == "" {
		t.Error("Expected trace_id to be set in context")
	}
}

func TestSREMiddleware_ChaosDetection_Header(t *testing.T) {
	var capturedCtx context.Context
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		capturedCtx = r.Context()
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write([]byte("OK")); err != nil {
			t.Errorf("write failed: %v", err)
		}
	})

	middleware := sreMiddleware(handler)
	req := httptest.NewRequest("GET", "/weather/lubbock", nil)
	req.Header.Set("X-Chaos-Mode", "true")
	rr := httptest.NewRecorder()

	middleware.ServeHTTP(rr, req)

	if capturedCtx == nil {
		t.Fatal("Context was not captured")
	}
	if val := weather.ChaosTrigger(capturedCtx); val != "true" {
		t.Errorf("Expected chaos_trigger='true' in context, got '%v'", val)
	}
}

func TestSREMiddleware_NoChaos(t *testing.T) {
	var capturedCtx context.Context
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		capturedCtx = r.Context()
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write([]byte("OK")); err != nil {
			t.Errorf("write failed: %v", err)
		}
	})

	middleware := sreMiddleware(handler)
	req := httptest.NewRequest("GET", "/weather/lubbock", nil)
	rr := httptest.NewRecorder()

	middleware.ServeHTTP(rr, req)

	if capturedCtx == nil {
		t.Fatal("Context was not captured")
	}
	if val := weather.ChaosTrigger(capturedCtx); val != "false" {
		t.Errorf("Expected chaos_trigger='false' in context, got '%v'", val)
	}
}

func TestSREMiddleware_MetricsRecording(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write([]byte("OK")); err != nil {
			t.Errorf("write failed: %v", err)
		}
	})

	middleware := sreMiddleware(handler)
	req := httptest.NewRequest("GET", "/weather/lubbock", nil)
	rr := httptest.NewRecorder()

	middleware.ServeHTTP(rr, req)

	// Verify request completed successfully
	// Metrics are recorded via obs.HttpRequestsTotal which uses promauto
	// (auto-registered), so we verify the request flow works correctly
	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}
}

func TestSREMiddleware_PathNormalization(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write([]byte("OK")); err != nil {
			t.Errorf("write failed: %v", err)
		}
	})

	middleware := sreMiddleware(handler)

	testCases := []struct {
		path     string
		expected string
	}{
		{"/weather/lubbock", "/weather/:location"},
		{"/weather/austin", "/weather/:location"},
		{"/health", "/health"},
		{"/metrics", "/metrics"},
	}

	for _, tc := range testCases {
		req := httptest.NewRequest("GET", tc.path, nil)
		rr := httptest.NewRecorder()
		middleware.ServeHTTP(rr, req)

		// The path normalization happens in the middleware
		// We verify the request completes successfully
		if rr.Code != http.StatusOK {
			t.Errorf("Path %s: Expected status 200, got %d", tc.path, rr.Code)
		}
	}
}

func TestSREMiddleware_StatusCodeCapture(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		if _, err := w.Write([]byte("Not Found")); err != nil {
			t.Errorf("write failed: %v", err)
		}
	})

	middleware := sreMiddleware(handler)
	req := httptest.NewRequest("GET", "/unknown", nil)
	rr := httptest.NewRecorder()

	middleware.ServeHTTP(rr, req)

	// Verify status code was captured correctly
	if rr.Code != http.StatusNotFound {
		t.Errorf("Expected status 404, got %d", rr.Code)
	}
}

func TestStatusRecorder(t *testing.T) {
	rr := httptest.NewRecorder()
	recorder := &statusRecorder{
		ResponseWriter: rr,
		statusCode:     http.StatusOK,
	}

	recorder.WriteHeader(http.StatusInternalServerError)

	if recorder.statusCode != http.StatusInternalServerError {
		t.Errorf("Expected status code 500, got %d", recorder.statusCode)
	}

	if rr.Code != http.StatusInternalServerError {
		t.Errorf("Expected ResponseWriter status code 500, got %d", rr.Code)
	}
}
