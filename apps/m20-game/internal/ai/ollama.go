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

// tonePrefix is prepended to all Ollama prompts to set the ZAMN campy B-movie tone.
const tonePrefix = "You are the narrator of a campy B-movie zombie apocalypse comedy — think Zombies Ate My Neighbors crossed with Army of Darkness. Be fun, slightly absurd, and dramatically over-the-top. The monsters are scary but also ridiculous. The survivors are heroic but also kind of ridiculous too."

// GenerateRiddle asks Ollama for a post-apocalyptic Sphinx riddle.
// Falls back to a hardcoded riddle if Ollama is unavailable.
func (c *Client) GenerateRiddle(ctx context.Context) RiddleResult {
	prompt := `You are the Sphinx — ancient, dramatic, and deeply committed to the bit.
Create a short riddle (2-3 lines) with a one-word answer.
The theme should be survival, decay, or the wasteland. Make it fun and slightly absurd.
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

// BuildingEntrance generates flavor text when a player enters a building.
// It sets the atmosphere before the monster group is revealed.
func (c *Client) BuildingEntrance(ctx context.Context, buildingName, groupName string) string {
	prompt := fmt.Sprintf(`%s
A survivor just kicked open the door of a %s and came face-to-face with "%s".
Write 2-3 sentences of B-movie atmospheric description: what they see, smell, or hear BEFORE the monsters notice them.
Be dramatic. Be slightly ridiculous. Under 60 words. No stage directions.`, tonePrefix, buildingName, groupName)

	resp, err := c.generate(ctx, "entrance", prompt)
	if err != nil || resp == "" {
		return fallbackEntrance(buildingName, groupName)
	}
	if len(resp) > 400 {
		resp = resp[:400]
	}
	return resp
}

// MonsterDialogue generates the opening line when a monster group spots the player.
func (c *Client) MonsterDialogue(ctx context.Context, monsterName string) string {
	prompt := fmt.Sprintf(`%s
You are a %s in a zombie apocalypse B-movie. You just noticed a survivor.
Say ONE line (under 15 words) that is menacing but also kind of ridiculous.
Stay in character. Be dramatic. No stage directions.`, tonePrefix, monsterName)

	resp, err := c.generate(ctx, "dialogue", prompt)
	if err != nil || resp == "" {
		return fallbackDialogue(monsterName)
	}
	if len(resp) > 150 {
		resp = resp[:150]
	}
	return resp
}

// CombatHit describes what a successful hit on a monster looks and feels like.
func (c *Client) CombatHit(ctx context.Context, monsterName, characterClass string, isCrit bool) string {
	intensity := "solid hit"
	if isCrit {
		intensity = "absolutely devastating, movie-worthy critical hit"
	}
	prompt := fmt.Sprintf(`%s
A %s lands a %s against a %s.
Describe the impact in ONE sentence (under 20 words). Be dramatic and slightly over-the-top. Present tense.`, tonePrefix, characterClass, intensity, monsterName)

	resp, err := c.generate(ctx, "combat_hit", prompt)
	if err != nil || resp == "" {
		return fallbackCombatHit(monsterName, isCrit)
	}
	if len(resp) > 200 {
		resp = resp[:200]
	}
	return resp
}

// CombatMiss describes a failed attack — the scramble, the near miss, the panic.
func (c *Client) CombatMiss(ctx context.Context, monsterName string, isCritFail bool) string {
	missType := "misses badly against"
	if isCritFail {
		missType = "catastrophically, hilariously fumbles against"
	}
	prompt := fmt.Sprintf(`%s
A survivor %s a %s.
Describe the miss in ONE sentence (under 20 words). Be dramatic and slightly humiliating. Present tense.`, tonePrefix, missType, monsterName)

	resp, err := c.generate(ctx, "combat_miss", prompt)
	if err != nil || resp == "" {
		return fallbackCombatMiss(monsterName, isCritFail)
	}
	if len(resp) > 200 {
		resp = resp[:200]
	}
	return resp
}

// MonsterDefeated describes the aftermath when all monsters in a group are beaten.
func (c *Client) MonsterDefeated(ctx context.Context, groupName, buildingName string) string {
	prompt := fmt.Sprintf(`%s
A survivor just cleared the "%s" inside a %s. Absolute victory. Probably got some on them.
Write ONE sentence (under 25 words) describing what the room looks like now. Be triumphant and slightly gross. Present tense.`, tonePrefix, groupName, buildingName)

	resp, err := c.generate(ctx, "victory", prompt)
	if err != nil || resp == "" {
		return fallbackVictory(groupName)
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

func fallbackEntrance(building, group string) string {
	return fmt.Sprintf("You kick open the door of the %s. It smells like bad decisions and something that used to be a person. The %s hasn't spotted you yet — which honestly feels like a personal insult.", building, group)
}

func fallbackDialogue(monster string) string {
	lines := map[string]string{
		"Zombie":       "...(groaning intensifies dramatically)...",
		"Vampire":      "You are SO overdressed for this apocalypse. Unlike me.",
		"Werewolf":     "*(low territorial growl that somehow sounds offended)*",
		"Mummy":        "I have been waiting 3,000 years for someone to bother me.",
		"Frankenstein": "NEW. THING. HERE. FRIEND? ...No.",
		"Basilisk":     "*(the sound of scales and very smug silence)*",
		"Golem":        "INTRUDER. PROTOCOL. INITIATED. HAVE A NICE DAY.",
		"Sphinx":       "Wrong answer means I eat you. Right answer means I also eat you. ...Kidding. Maybe.",
		"Wraith":       "*(the temperature drops and something is VERY upset)*",
		"Windego":      "I remember being human once. I also remember pizza. Both are gone.",
	}
	if line, ok := lines[monster]; ok {
		return line
	}
	return fmt.Sprintf("The %s looks at you with the energy of someone who has been waiting all day for this.", monster)
}

func fallbackCombatHit(monster string, isCrit bool) string {
	if isCrit {
		return fmt.Sprintf("SPECTACULAR hit — the %s does the full movie stagger and lands in something unfortunate.", monster)
	}
	return fmt.Sprintf("Your attack connects! The %s reels dramatically. Points for commitment.", monster)
}

func fallbackCombatMiss(monster string, isCritFail bool) string {
	if isCritFail {
		return fmt.Sprintf("You trip over literally nothing and the %s judges you openly for it.", monster)
	}
	return fmt.Sprintf("Swing and a miss! The %s seems almost embarrassed for you.", monster)
}

func fallbackVictory(group string) string {
	return fmt.Sprintf("The %s is history. You do a mental victory lap. The room is yours now. It smells terrible. Totally worth it.", group)
}
