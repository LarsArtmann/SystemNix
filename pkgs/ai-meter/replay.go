package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"os"
	"time"
)

// ReplaySummary accounts for one pass over the ledger.
type ReplaySummary struct {
	Calls   int     // entries folded into the cost counter
	Skipped int     // lines that did not parse; left out of every counter
	CostUSD float64 // cost of the folded entries at the current price table
}

// ReplayCosts folds every call the ledger has recorded into the cost counter
// at the CURRENT price table. The counter therefore means "since the ledger
// began", survives restarts, and restates itself whenever a price row lands
// or changes: usage metered before a model had a price is priced the moment
// the row ships, with no backfill step.
//
// Only the cost family is restored. Requests, tokens and latency keep their
// restart-reset semantics on purpose: rate() absorbs a reset, whereas a
// re-baselined cumulative counter reads as one enormous spike in every rate
// panel and ratio alert that consumes it.
func (l *Ledger) ReplayCosts(cfg *Config, registry *Registry) (ReplaySummary, error) {
	file, err := os.Open(l.path)
	if err != nil {
		return ReplaySummary{}, err
	}
	defer func() { _ = file.Close() }()
	info, err := file.Stat()
	if err != nil {
		return ReplaySummary{}, err
	}
	// Only what the ledger held when the replay began. Calls appended after
	// that moment are folded in live by the request path; reading them here
	// as well would count them twice.
	return replayCosts(io.LimitReader(file, info.Size()), cfg, registry)
}

func replayCosts(input io.Reader, cfg *Config, registry *Registry) (ReplaySummary, error) {
	var summary ReplaySummary
	reader := bufio.NewReaderSize(input, 64*1024)
	for {
		line, err := reader.ReadBytes('\n')
		if len(bytes.TrimSpace(line)) > 0 {
			var entry ledgerEntry
			// A line that is not a recorded call (torn write, foreign
			// content) is skipped, never fatal: it cannot be priced, and
			// refusing to serve over it would take down every routed call.
			if json.Unmarshal(line, &entry) != nil || entry.Client == "" {
				summary.Skipped++
			} else {
				call := entry.call()
				cfg.Price(&call)
				registry.RestoreCost(call)
				summary.Calls++
				summary.CostUSD += call.CostUSD
			}
		}
		if err != nil {
			if err == io.EOF {
				break
			}
			return summary, err
		}
	}
	return summary, nil
}

// seedCostCounter primes the cost counter from the ledger while the proxy is
// already serving: the ledger grows without bound, and its size must never
// lengthen the window in which routed calls fail. Until the pass ends the
// cost counter reads low by the replayed amount, which no rate panel or
// alert consumes. It must never fail the proxy: every error is counted and
// logged, and the proxy then runs with a cost counter that begins at zero.
func seedCostCounter(cfg *Config, ledger *Ledger, registry *Registry, logger *slog.Logger) {
	started := time.Now()
	summary, err := ledger.ReplayCosts(cfg, registry)
	if err != nil {
		registry.MeteringError()
		logger.Error("ledger replay failed - the cost counter starts from zero for this process", "err", err)
	}
	for range summary.Skipped {
		registry.MeteringError()
	}
	if summary.Skipped > 0 {
		logger.Error("ledger has unparseable lines - their calls are missing from the cost counter", "skipped", summary.Skipped)
	}
	logger.Info(
		"ledger replayed",
		"calls", summary.Calls,
		"cost_usd", summary.CostUSD,
		"skipped", summary.Skipped,
		"elapsed_ms", time.Since(started).Milliseconds(),
	)
}
