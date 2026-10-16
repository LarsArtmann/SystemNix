package main

import (
	"encoding/json"
	"log/slog"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Ledger is the durable append-only usage log — one JSON object per line,
// the true-up source for anything the (restart-resettable) Prometheus
// counters show.
type Ledger struct {
	mu     sync.Mutex
	file   *os.File
	logger *slog.Logger
}

type ledgerEntry struct {
	Time             string  `json:"time"`
	Client           string  `json:"client"`
	Upstream         string  `json:"upstream"`
	Model            string  `json:"model"`
	Status           int     `json:"status"`
	Stream           bool    `json:"stream"`
	Path             string  `json:"path"`
	PromptTokens     int     `json:"prompt_tokens"`
	CompletionTokens int     `json:"completion_tokens"`
	CachedTokens     int     `json:"cached_tokens"`
	TotalTokens      int     `json:"total_tokens"`
	CostUSD          float64 `json:"cost_usd"`
	DurationMS       int64   `json:"duration_ms"`
	TTFTMS           int64   `json:"ttft_ms"`
	UsageMissing     bool    `json:"usage_missing,omitempty"`
}

func OpenLedger(path string, logger *slog.Logger) (*Ledger, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, err
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return nil, err
	}
	return &Ledger{file: file, logger: logger}, nil
}

// Append records one call. Errors are returned (the caller counts them as
// metering errors) but never fail live traffic.
func (l *Ledger) Append(rec Record) error {
	ttft := rec.TTFTMS
	if !rec.Stream || ttft < 0 {
		ttft = -1
	}
	entry := ledgerEntry{
		Time:             time.Now().UTC().Format(time.RFC3339Nano),
		Client:           rec.Client,
		Upstream:         rec.Upstream,
		Model:            rec.Model,
		Status:           rec.Status,
		Stream:           rec.Stream,
		Path:             rec.Path,
		PromptTokens:     rec.PromptTokens,
		CompletionTokens: rec.CompletionTokens,
		CachedTokens:     rec.CachedTokens,
		TotalTokens:      rec.PromptTokens + rec.CompletionTokens,
		CostUSD:          rec.CostUSD,
		DurationMS:       rec.DurationMS,
		TTFTMS:           ttft,
		UsageMissing:     rec.UsageMissing,
	}
	line, err := json.Marshal(entry)
	if err != nil {
		return err
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if _, err := l.file.Write(append(line, '\n')); err != nil {
		return err
	}
	return l.file.Sync()
}

func (l *Ledger) Close() error {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.file.Close()
}
