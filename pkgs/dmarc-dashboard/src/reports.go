// Package main implements the DMARC dashboard: a small read-only web UI
// over parsedmarc's aggregate.json output (runbook: docs/services/
// dmarc-dashboard.md).
//
// parsedmarc 11 appends parsed DMARC aggregate reports into a single JSON
// array file (<output>/aggregate.json). This service reads that file on
// request, keeps the last good copy in memory if a read races parsedmarc's
// rewrite, and renders a server-side HTML view (no client JS, no state).
package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"sync"
	"syscall"
	"time"
)

// store caches the last successfully parsed aggregate.json so a read that
// races parsedmarc's read-merge-rewrite cycle serves stale data instead of
// failing the page.
type store struct {
	dir string

	mu       sync.RWMutex
	reports  []AggregateReport
	modTime  time.Time
	lastErr  error
	hasCache bool
}

func newStore(dir string) *store {
	return &store{dir: dir}
}

func (s *store) path() string {
	return s.dir + "/aggregate.json"
}

// load reads aggregate.json and returns the parsed reports plus the file's
// modification time. On a parse or read error it falls back to the last
// good cache, reporting the error alongside.
func (s *store) load() ([]AggregateReport, time.Time, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	st, err := os.Stat(s.path())
	if err != nil {
		s.lastErr = err
		if s.hasCache {
			return s.reports, s.modTime, fmt.Errorf("reading %s: %w (serving last good copy from %s)", s.path(), err, s.modTime.Format(time.RFC3339))
		}
		return nil, time.Time{}, fmt.Errorf("reading %s: %w", s.path(), err)
	}

	if s.hasCache && s.modTime.Equal(st.ModTime()) {
		return s.reports, s.modTime, nil
	}

	raw, err := os.ReadFile(s.path())
	if err != nil {
		s.lastErr = err
		if s.hasCache {
			return s.reports, s.modTime, fmt.Errorf("reading %s: %w (serving last good copy from %s)", s.path(), err, s.modTime.Format(time.RFC3339))
		}
		return nil, time.Time{}, fmt.Errorf("reading %s: %w", s.path(), err)
	}

	var reports []AggregateReport
	if err := json.Unmarshal(raw, &reports); err != nil {
		s.lastErr = err
		if s.hasCache {
			return s.reports, s.modTime, fmt.Errorf("parsing %s: %w (serving last good copy from %s)", s.path(), err, s.modTime.Format(time.RFC3339))
		}
		return nil, time.Time{}, fmt.Errorf("parsing %s: %w", s.path(), err)
	}

	for i := range reports {
		reports[i].normalize()
	}

	s.reports = reports
	s.modTime = st.ModTime()
	s.lastErr = nil
	s.hasCache = true
	return s.reports, s.modTime, nil
}

// exists reports whether the reports directory is present and readable.
func (s *store) exists() bool {
	_, err := os.Stat(s.path())
	return err == nil
}

// statDevIno returns the file's device/inode pair for diagnostics.
func (s *store) statDevIno() (dev uint64, ino uint64, ok bool) {
	st, err := os.Stat(s.path())
	if err != nil {
		return 0, 0, false
	}
	if sys, isStat := st.Sys().(*syscall.Stat_t); isStat {
		return uint64(sys.Dev), uint64(sys.Ino), true
	}
	return 0, 0, false
}
