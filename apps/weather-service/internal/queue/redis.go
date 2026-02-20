package queue

import (
	"context"
	"encoding/json"
	"log/slog"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

const defaultQueueName = "weather:jobs"

// Job represents a weather lookup request in the queue.
type Job struct {
	Location string `json:"location"`
	Chaos    bool   `json:"chaos"`
}

// Client wraps Redis operations for the weather job queue.
type Client struct {
	rdb  *redis.Client
	name string
}

// NewClient creates a Redis queue client. Uses REDIS_ADDR and REDIS_QUEUE_NAME from env.
func NewClient() *Client {
	addr := getEnv("REDIS_ADDR", "localhost:6379")
	name := getEnv("REDIS_QUEUE_NAME", defaultQueueName)

	rdb := redis.NewClient(&redis.Options{
		Addr:         addr,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 5 * time.Second,
	})

	return &Client{rdb: rdb, name: name}
}

// Push adds a job to the queue (left push for FIFO with BRPOP).
func (c *Client) Push(ctx context.Context, job *Job) error {
	data, err := json.Marshal(job)
	if err != nil {
		return err
	}
	return c.rdb.LPush(ctx, c.name, data).Err()
}

// PushMany bulk-pushes jobs to the queue for fast chaos loading.
func (c *Client) PushMany(ctx context.Context, jobs []*Job) (int, error) {
	if len(jobs) == 0 {
		return 0, nil
	}
	args := make([]interface{}, len(jobs))
	for i, job := range jobs {
		data, err := json.Marshal(job)
		if err != nil {
			return i, err
		}
		args[i] = data
	}
	err := c.rdb.LPush(ctx, c.name, args...).Err()
	if err != nil {
		return 0, err
	}
	return len(jobs), nil
}

// Pop blocks until a job is available, or context is cancelled.
func (c *Client) Pop(ctx context.Context) (*Job, error) {
	res, err := c.rdb.BRPop(ctx, 0, c.name).Result()
	if err != nil {
		return nil, err
	}
	if len(res) < 2 {
		return nil, nil
	}
	var job Job
	if err := json.Unmarshal([]byte(res[1]), &job); err != nil {
		slog.Warn("queue: failed to unmarshal job", "raw", res[1], "error", err)
		return nil, err
	}
	return &job, nil
}

// Len returns the current queue length (for metrics and KEDA).
func (c *Client) Len(ctx context.Context) (int64, error) {
	return c.rdb.LLen(ctx, c.name).Result()
}

// Close closes the Redis connection.
func (c *Client) Close() error {
	return c.rdb.Close()
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
