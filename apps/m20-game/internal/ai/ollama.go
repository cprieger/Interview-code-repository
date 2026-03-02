// Package ai wraps the Ollama local LLM for game-flavored AI responses.
// Riddles power the Sphinx encounter. Monster dialogue adds flavour text.
// Falls back gracefully if Ollama is unavailable — the game still works.
package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"m20-game/internal/obs"
)

// Client calls the Ollama API.
type Client struct {
	baseURL    string
	model      string
	httpClient *http.Client
}

// NewClient creates an Ollama AI client.
func NewClient(baseURL string) *Client {
	return &Client{
		baseURL: baseURL,
		model:   "llama3.2:1b",
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

type ollamaRequest struct {
	Model  string `json:"model"`
	Prompt string `json:"prompt"`
	Stream bool   `json:"stream"`
}

type ollamaResponse struct {
	Response string `json:"response"`
	Done     bool   `json:"done"`
}

// generate sends a prompt to Ollama and returns the response text.
func (c *Client) generate(ctx context.Context, reqType, prompt string) (string, error) {
	start := time.Now()

	body, _ := json.Marshal(ollamaRequest{
		Model:  c.model,
		Prompt: prompt,
		Stream: false,
	})

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/generate", bytes.NewReader(body))
	if err != nil {
		obs.AIRequestsTotal.WithLabelValues(reqType, "error").Inc()
		return "", fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		status := "error"
		if ctx.Err() != nil {
			status = "timeout"
		}
		obs.AIRequestsTotal.WithLabelValues(reqType, status).Inc()
		return "", fmt.Errorf("ollama request: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		obs.AIRequestsTotal.WithLabelValues(reqType, "error").Inc()
		return "", fmt.Errorf("read response: %w", err)
	}

	var result ollamaResponse
	if err := json.Unmarshal(data, &result); err != nil {
		obs.AIRequestsTotal.WithLabelValues(reqType, "error").Inc()
		return "", fmt.Errorf("decode response: %w", err)
	}

	obs.AIRequestsTotal.WithLabelValues(reqType, "success").Inc()
	obs.AIRequestDuration.WithLabelValues(reqType).Observe(time.Since(start).Seconds())

	return result.Response, nil
}

// RiddleResult is a Sphinx riddle with its answer.
type RiddleResult struct {
	Riddle   string `json:"riddle"`
	Answer   string `json:"answer"`
	Fallback bool   `json:"fallback"` // true if Ollama was unavailable
}

// GenerateRiddle asks Ollama for a post-apocalyptic Sphinx riddle.
// Falls back to a hardcoded riddle if Ollama is unavailable.
func (c *Client) GenerateRiddle(ctx context.Context) RiddleResult {
	prompt := `You are the Sphinx in a post-apocalyptic dungeon.
Create a short riddle (2-3 lines) with a one-word answer.
The theme should be survival, decay, or the wasteland.
Format: RIDDLE: [riddle text] ANSWER: [one word]`

	resp, err := c.generate(ctx, "riddle", prompt)
	if err != nil {
		return fallbackRiddle()
	}

	// Parse RIDDLE/ANSWER format from response
	riddle, answer := parseRiddleResponse(resp)
	if riddle == "" {
		return fallbackRiddle()
	}

	return RiddleResult{Riddle: riddle, Answer: answer}
}

// MonsterDialogue generates flavour text for a monster encounter.
func (c *Client) MonsterDialogue(ctx context.Context, monsterName string) string {
	prompt := fmt.Sprintf(`You are a %s in a post-apocalyptic dungeon.
Say one menacing sentence (under 20 words) to a survivor you're about to fight.
Be in character. No meta-commentary.`, monsterName)

	resp, err := c.generate(ctx, "dialogue", prompt)
	if err != nil {
		return fallbackDialogue(monsterName)
	}

	if len(resp) > 200 {
		resp = resp[:200]
	}
	return resp
}

func parseRiddleResponse(s string) (riddle, answer string) {
	riddleIdx := findIndex(s, "RIDDLE:")
	answerIdx := findIndex(s, "ANSWER:")
	if riddleIdx == -1 || answerIdx == -1 {
		return "", ""
	}
	riddle = s[riddleIdx+7 : answerIdx]
	answer = s[answerIdx+7:]
	return trim(riddle), trim(answer)
}

func findIndex(s, substr string) int {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}

func trim(s string) string {
	start, end := 0, len(s)
	for start < end && (s[start] == ' ' || s[start] == '\n' || s[start] == '\r') {
		start++
	}
	for end > start && (s[end-1] == ' ' || s[end-1] == '\n' || s[end-1] == '\r') {
		end--
	}
	return s[start:end]
}

func fallbackRiddle() RiddleResult {
	return RiddleResult{
		Riddle:   "I am always ahead of you but never in front. What am I?",
		Answer:   "Tomorrow",
		Fallback: true,
	}
}

func fallbackDialogue(monster string) string {
	return fmt.Sprintf("The %s regards you with ancient, terrible patience.", monster)
}
