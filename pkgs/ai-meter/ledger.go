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
//
// A line records FACTS only: who called what, and how many tokens came
// back. Cost is deliberately not stored. It is a derivation (tokens x the
// price table), and the table changes: a row lands late, a price gets
// corrected. A stored cost would go stale the moment it does, so cost is
// recomputed wherever it is shown (EstimateCost, ReplayCosts).
type Ledger struct {
	mu     sync.Mutex
	path   string
	file   *os.File
	logger *slog.Logger
}

type ledgerEntry struct {
	Time             string `json:"time"`
	Client           string `json:"client"`
	Upstream         string `json:"upstream"`
	Model            string `json:"model"`
	Status           int    `json:"status"`
	Stream           bool   `json:"stream"`
	Path             string `json:"path"`
	PromptTokens     int    `json:"prompt_tokens"`
	CompletionTokens int    `json:"completion_tokens"`
	CachedTokens     int    `json:"cached_tokens"`
	TotalTokens      int    `json:"total_tokens"`
	DurationMS       int64  `json:"duration_ms"`
	TTFTMS           int64  `json:"ttft_ms"`
	UsageMissing     bool   `json:"usage_missing,omitempty"`
}

// call maps a stored entry back to the call it recorded. Cost stays zero:
// the caller prices it at the CURRENT table.
func (e ledgerEntry) call() Record {
	return Record{
		Client:           e.Client,
		Upstream:         e.Upstream,
		Model:            modelName(e.Model),
		Status:           e.Status,
		Stream:           e.Stream,
		Path:             e.Path,
		PromptTokens:     e.PromptTokens,
		CompletionTokens: e.CompletionTokens,
		CachedTokens:     e.CachedTokens,
		DurationMS:       e.DurationMS,
		TTFTMS:           e.TTFTMS,
		UsageMissing:     e.UsageMissing,
	}
}

func OpenLedger(path string, logger *slog.Logger) (*Ledger, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, err
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return nil, err
	}
	ledger := &Ledger{path: path, file: file, logger: logger}
	if err := ledger.terminateTornTail(); err != nil {
		// Never a reason to refuse traffic: the next append then lands on
		// the same line, and ReplayCosts skips both as unparseable.
		logger.Warn("ledger tail check failed", "err", err)
	}
	return ledger, nil
}

// terminateTornTail ends a final line that lacks its newline (a write cut by
// a crash or a full disk). Without this the next append joins the torn line
// and BOTH entries become unparseable; with it exactly one is lost.
func (l *Ledger) terminateTornTail() error {
	reader, err := os.Open(l.path)
	if err != nil {
		return err
	}
	defer func() { _ = reader.Close() }()
	info, err := reader.Stat()
	if err != nil {
		return err
	}
	if info.Size() == 0 {
		return nil
	}
	last := []byte{0}
	if _, err := reader.ReadAt(last, info.Size()-1); err != nil {
		return err
	}
	if last[0] == '\n' {
		return nil
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	_, err = l.file.Write([]byte{'\n'})
	return err
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
