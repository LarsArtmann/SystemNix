package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

func quietLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

func testAdmission() AdmissionConfig {
	return AdmissionConfig{
		MaxConcurrency: 4,
		MinConcurrency: 1,
		MaxWait:        30 * time.Second,
		MaxRetries:     6,
		GrowAfter:      30 * time.Second,
		RetryableCodes: map[string]bool{"1302": true, "1305": true},
		QuotaCodes:     map[string]bool{"1308": true},
	}
}

// clockedGate is a gate whose time the test moves with a pointer.
func clockedGate(cfg AdmissionConfig) (*Gate, *time.Time) {
	g := NewGate("fake", cfg, NewRegistry(), quietLogger())
	clock := time.Date(2026, 11, 25, 12, 0, 0, 0, time.UTC)
	g.now = func() time.Time { return clock }
	g.changedAt = clock
	return g, &clock
}

func (g *Gate) allowance() int {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.limit
}

func (g *Gate) snapshot() (inflight, waiting int) {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.inflight, len(g.waiters)
}

// takeAndRelease runs one call through the gate without waiting.
func takeAndRelease(t *testing.T, g *Gate) {
	t.Helper()
	if _, err := g.acquire(context.Background(), false); err != nil {
		t.Fatalf("acquire: %v", err)
	}
	g.Release()
}

func awaitFor(t *testing.T, what string, condition func() bool) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for !condition() {
		if time.Now().After(deadline) {
			t.Fatalf("timed out waiting for %s", what)
		}
		time.Sleep(2 * time.Millisecond)
	}
}

func TestGateAllowanceDropsOnRejectionAndGrowsBackAfterQuiet(t *testing.T) {
	g, clock := clockedGate(testAdmission())

	g.rejected()
	g.rejected()
	if got := g.allowance(); got != 3 {
		t.Fatalf("two rejections in one burst lowered the allowance twice: %d", got)
	}
	*clock = clock.Add(2 * time.Second)
	g.rejected()
	if got := g.allowance(); got != 2 {
		t.Fatalf("allowance after a later rejection = %d, want 2", got)
	}

	*clock = clock.Add(29 * time.Second)
	takeAndRelease(t, g)
	if got := g.allowance(); got != 2 {
		t.Fatalf("allowance grew before the quiet interval: %d", got)
	}
	*clock = clock.Add(time.Second)
	takeAndRelease(t, g)
	if got := g.allowance(); got != 3 {
		t.Fatalf("allowance after the quiet interval = %d, want 3", got)
	}
	*clock = clock.Add(30 * time.Second)
	takeAndRelease(t, g)
	if got := g.allowance(); got != 4 {
		t.Fatalf("allowance after a second quiet interval = %d, want 4", got)
	}
	*clock = clock.Add(time.Hour)
	takeAndRelease(t, g)
	if got := g.allowance(); got != 4 {
		t.Fatalf("allowance grew past its ceiling: %d", got)
	}
}

func TestGateFailedProbeWaitsLongerBeforeTheNextOne(t *testing.T) {
	g, clock := clockedGate(testAdmission())

	g.rejected()
	*clock = clock.Add(2 * time.Second)
	g.rejected()
	if got := g.allowance(); got != 2 {
		t.Fatalf("allowance = %d, want 2", got)
	}

	*clock = clock.Add(30 * time.Second)
	takeAndRelease(t, g)
	if got := g.allowance(); got != 3 {
		t.Fatalf("allowance did not probe upward after the interval: %d", got)
	}
	*clock = clock.Add(time.Second)
	g.rejected()
	if got := g.allowance(); got != 2 {
		t.Fatalf("the rejected probe stayed up: %d", got)
	}

	*clock = clock.Add(59 * time.Second)
	takeAndRelease(t, g)
	if got := g.allowance(); got != 2 {
		t.Fatalf("the next probe came before the doubled interval: %d", got)
	}
	*clock = clock.Add(time.Second)
	takeAndRelease(t, g)
	if got := g.allowance(); got != 3 {
		t.Fatalf("the next probe did not come after the doubled interval: %d", got)
	}
}

func TestGateStopsAtItsFloorAndStillWaitsBeforeItProbes(t *testing.T) {
	cfg := testAdmission()
	cfg.MaxConcurrency, cfg.MinConcurrency = 2, 1
	g, clock := clockedGate(cfg)

	g.rejected()
	*clock = clock.Add(2 * time.Second)
	g.rejected()
	if got := g.allowance(); got != 1 {
		t.Fatalf("allowance went below its floor: %d", got)
	}
	takeAndRelease(t, g)
	if got := g.allowance(); got != 1 {
		t.Fatalf("the floor was left without an interval: %d", got)
	}
	*clock = clock.Add(30 * time.Second)
	takeAndRelease(t, g)
	if got := g.allowance(); got != 2 {
		t.Fatalf("allowance did not leave its floor after the interval: %d", got)
	}
}

func TestGateQueuesCallsInArrivalOrder(t *testing.T) {
	cfg := testAdmission()
	cfg.MaxConcurrency = 1
	g, _ := clockedGate(cfg)
	ctx := context.Background()
	if waited, err := g.acquire(ctx, false); err != nil || waited {
		t.Fatalf("acquire within the allowance: waited %t, err %v", waited, err)
	}

	admitted := make(chan int, 3)
	for i := 3; i <= 5; i++ {
		go func() {
			if _, err := g.acquire(ctx, false); err != nil {
				t.Errorf("queued acquire: %v", err)
			}
			admitted <- i
		}()
		// The next call must arrive after this one is queued, or the
		// order under test is the scheduler's, not the gate's.
		awaitFor(t, "a call to queue", func() bool {
			_, waiting := g.snapshot()
			return waiting == i-2
		})
	}
	if inflight, _ := g.snapshot(); inflight != 1 {
		t.Fatalf("calls in flight = %d, want the allowance of 1", inflight)
	}

	// Each release hands the one slot to the call that queued first.
	for i := 3; i <= 5; i++ {
		g.Release()
		select {
		case got := <-admitted:
			if got != i {
				t.Fatalf("call %d was admitted where call %d should have gone first", got, i)
			}
		case <-time.After(5 * time.Second):
			t.Fatalf("call %d was never admitted", i)
		}
	}
	if inflight, waiting := g.snapshot(); inflight != 1 || waiting != 0 {
		t.Fatalf("after handing the slot on: in flight %d, waiting %d", inflight, waiting)
	}
}

func TestGateRetryRejoinsAheadOfTheQueue(t *testing.T) {
	cfg := testAdmission()
	cfg.MaxConcurrency = 1
	g, _ := clockedGate(cfg)
	ctx := context.Background()
	if _, err := g.acquire(ctx, false); err != nil {
		t.Fatal(err)
	}
	admitted := make(chan string, 2)
	later := make(chan struct{})
	go func() {
		if _, err := g.acquire(ctx, false); err != nil {
			t.Errorf("acquire: %v", err)
		}
		admitted <- "fresh"
	}()
	awaitFor(t, "the fresh call to queue", func() bool {
		_, waiting := g.snapshot()
		return waiting == 1
	})
	go func() {
		close(later)
		if _, err := g.acquire(ctx, true); err != nil {
			t.Errorf("acquire: %v", err)
		}
		admitted <- "retry"
	}()
	<-later
	awaitFor(t, "the retry to queue", func() bool {
		_, waiting := g.snapshot()
		return waiting == 2
	})

	g.Release()
	if got := <-admitted; got != "retry" {
		t.Fatalf("%s was admitted first, want the retry ahead of the call that queued before it", got)
	}
	g.Release()
	if got := <-admitted; got != "fresh" {
		t.Fatalf("%s was admitted second", got)
	}
}

func TestGateACallThatGivesUpLeavesNoSlotBehind(t *testing.T) {
	cfg := testAdmission()
	cfg.MaxConcurrency = 1
	g, _ := clockedGate(cfg)
	ctx := context.Background()
	if _, err := g.acquire(ctx, false); err != nil {
		t.Fatal(err)
	}

	ctx, cancel := context.WithCancel(ctx)
	queued := make(chan error, 1)
	go func() {
		_, err := g.acquire(ctx, false)
		queued <- err
	}()
	awaitFor(t, "the call to queue", func() bool {
		_, waiting := g.snapshot()
		return waiting == 1
	})
	cancel()
	if err := <-queued; !errors.Is(err, context.Canceled) {
		t.Fatalf("a cancelled wait returned %v", err)
	}
	if inflight, waiting := g.snapshot(); inflight != 1 || waiting != 0 {
		t.Fatalf("after the cancelled wait: in flight %d, waiting %d", inflight, waiting)
	}

	// The freed slot goes to nobody: nothing is left that could take it.
	g.Release()
	if inflight, waiting := g.snapshot(); inflight != 0 || waiting != 0 {
		t.Fatalf("after the last release: in flight %d, waiting %d", inflight, waiting)
	}
}

func TestGateLosesNoSlotWhenCallsGiveUpWhileSlotsAreHandedOn(t *testing.T) {
	g, _ := clockedGate(testAdmission())
	ctx := context.Background()

	var wg sync.WaitGroup
	for n := range 300 {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			callCtx, cancel := context.WithTimeout(ctx, time.Duration(n%7)*time.Millisecond)
			defer cancel()
			waited, err := g.acquire(callCtx, n%5 == 0)
			if err != nil {
				return
			}
			if waited {
				time.Sleep(time.Duration(n%3) * time.Millisecond)
			}
			g.Release()
		}(n)
	}
	wg.Wait()
	if inflight, waiting := g.snapshot(); inflight != 0 || waiting != 0 {
		t.Fatalf("after every call left: in flight %d, waiting %d", inflight, waiting)
	}
}

func TestGateQuotaCircuitOpensUntilTheResetAndNoLonger(t *testing.T) {
	g, clock := clockedGate(testAdmission())
	base := *clock
	reset := base.Add(time.Hour)

	g.exhausted(base.Add(-time.Second), []byte("past"), "", "1308")
	if _, blocked := g.quotaBlocked(); blocked {
		t.Fatal("a reset in the past opened the circuit")
	}
	g.exhausted(base.Add(9*24*time.Hour), []byte("far"), "", "1308")
	if _, blocked := g.quotaBlocked(); blocked {
		t.Fatal("a reset nine days out opened the circuit")
	}

	g.exhausted(reset, []byte("quota"), "application/json", "1308")
	quota, blocked := g.quotaBlocked()
	if !blocked || !quota.until.Equal(reset) || string(quota.body) != "quota" || quota.contentType != "application/json" || quota.code != "1308" {
		t.Fatalf("circuit state = %+v, blocked %t", quota, blocked)
	}
	g.exhausted(base.Add(time.Minute), []byte("earlier"), "", "1308")
	if quota, _ := g.quotaBlocked(); !quota.until.Equal(reset) {
		t.Fatalf("an earlier reset shortened the circuit to %v", quota.until)
	}

	*clock = reset
	if _, blocked := g.quotaBlocked(); blocked {
		t.Fatal("the circuit stayed closed past the reset")
	}
}

func TestPendingIsNotSentWhileTheQuotaIsSpent(t *testing.T) {
	g, clock := clockedGate(testAdmission())
	base := *clock
	g.exhausted(base.Add(time.Hour), []byte("quota"), "application/json", "1308")

	call := g.open(base)
	err := call.enter(context.Background())
	var quota *quotaRejection
	if !errors.As(err, &quota) || !quota.until.Equal(base.Add(time.Hour)) || string(quota.body) != "quota" {
		t.Fatalf("enter = %v, want the upstream's quota answer back", err)
	}
	if inflight, _ := g.snapshot(); inflight != 0 {
		t.Fatalf("a call that was not sent holds %d slots", inflight)
	}
}

func TestPendingWaitsForAResetWithinItsBudget(t *testing.T) {
	g, clock := clockedGate(testAdmission())
	base := *clock
	guard := quotaResetGuard
	quotaResetGuard = 0
	t.Cleanup(func() { quotaResetGuard = guard })

	// The reset lands inside the budget: the call waits for it and is sent.
	g.exhausted(base.Add(2*time.Second), []byte("quota"), "application/json", "1308")
	*clock = base.Add(2*time.Second - 20*time.Millisecond)
	call := g.open(base)
	if err := call.enter(context.Background()); err != nil {
		t.Fatalf("enter = %v, want a slot once the window reset", err)
	}
	call.leave()
	if inflight, _ := g.snapshot(); inflight != 0 {
		t.Fatalf("slot not given back: in flight %d", inflight)
	}

	// Past the reset the circuit stays closed, whatever it knew.
	g.exhausted(base.Add(4*time.Second), []byte("quota"), "application/json", "1308")
	*clock = base.Add(5 * time.Second)
	call = g.open(*clock)
	if err := call.enter(context.Background()); err != nil {
		t.Fatalf("enter after the reset = %v", err)
	}
	call.leave()
}

func TestPendingOutlivesItsBudgetOnlyAsAnError(t *testing.T) {
	ctx := context.Background()
	cfg := testAdmission()
	cfg.MaxConcurrency, cfg.MaxWait = 1, 20*time.Millisecond
	short := NewGate("short", cfg, NewRegistry(), quietLogger())
	if _, err := short.acquire(ctx, false); err != nil {
		t.Fatal(err)
	}
	call := short.open(time.Now())
	started := time.Now()
	if err := call.enter(ctx); !errors.Is(err, errAdmissionTimeout) {
		t.Fatalf("enter = %v, want the wait budget to run out", err)
	}
	if waited := time.Since(started); waited < 20*time.Millisecond {
		t.Fatalf("enter gave up after %v, before the budget", waited)
	}
	short.Release()
	if inflight, waiting := short.snapshot(); inflight != 1 || waiting != 0 {
		t.Fatalf("the call that gave up left a mark: in flight %d, waiting %d", inflight, waiting)
	}
}

func TestPendingBackoffGrowsToItsCeilingAndStaysInItsRange(t *testing.T) {
	g, _ := clockedGate(testAdmission())
	call := g.open(time.Now())
	for rejection := 1; rejection <= 9; rejection++ {
		call.rejected = rejection
		ceiling := min(retryBase<<min(rejection-1, maxRetriesForBackoff), retryCeiling)
		for range 50 {
			if delay := call.backoff(); delay < ceiling/4 || delay >= ceiling {
				t.Fatalf("backoff after %d rejections = %v, outside [%v, %v)", rejection, delay, ceiling/4, ceiling)
			}
		}
	}
}

func TestAdmissionSettingsFillDefaultsAndRefuseWhatCannotWork(t *testing.T) {
	plain := AdmissionSettings{MaxConcurrency: 3, RetryableCodes: []string{"1302", " 1305 "}}
	cfg, err := plain.config()
	if err != nil {
		t.Fatalf("plain settings: %v", err)
	}
	if cfg.MinConcurrency != 1 || cfg.MaxWait != defaultMaxWait || cfg.MaxRetries != defaultMaxRetries || cfg.GrowAfter != defaultGrowAfter {
		t.Fatalf("defaults not filled: %+v", cfg)
	}
	if !cfg.RetryableCodes["1302"] || !cfg.RetryableCodes["1305"] || cfg.RetryableCodes[" 1305 "] {
		t.Fatalf("retryable codes = %v", cfg.RetryableCodes)
	}

	for name, bad := range map[string]AdmissionSettings{
		"no ceiling":          {RetryableCodes: []string{"1302"}},
		"floor above ceiling": {MaxConcurrency: 2, MinConcurrency: 3, RetryableCodes: []string{"1302"}},
		"negative floor":      {MaxConcurrency: 2, MinConcurrency: -1, RetryableCodes: []string{"1302"}},
		"negative wait":       {MaxConcurrency: 2, MaxWaitSeconds: -1, RetryableCodes: []string{"1302"}},
		"negative retries":    {MaxConcurrency: 2, MaxRetries: -1, RetryableCodes: []string{"1302"}},
		"negative grow":       {MaxConcurrency: 2, GrowAfterSeconds: -1, RetryableCodes: []string{"1302"}},
		"zone beyond a day":   {MaxConcurrency: 2, QuotaResetUTCOffsetHours: 25, RetryableCodes: []string{"1302"}},
		"nothing to retry":    {MaxConcurrency: 2},
	} {
		if _, err := bad.config(); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}

func TestClassifyReadsTheBusinessCodeBeforeTheWording(t *testing.T) {
	cfg := testAdmission()
	for name, tc := range map[string]struct {
		body string
		want rejectionKind
		code string
	}{
		"retryable code":                {`{"error":{"code":"1302","message":"Rate limit reached for requests"}}`, kindRateLimit, "1302"},
		"numeric code":                  {`{"error":{"code":1302,"message":"Rate limit reached for requests"}}`, kindRateLimit, "1302"},
		"quota code":                    {`{"error":{"code":"1308","message":"Usage limit reached for 5 hour. Your limit will reset at 2026-11-15 23:51:01"}}`, kindQuota, "1308"},
		"unknown code with a reset":     {`{"error":{"code":"1399","message":"Resets at 2026-11-15 23:51:01"}}`, kindQuota, "1399"},
		"no code, rate limit wording":   {`{"error":{"message":"Rate limit reached for requests"}}`, kindRateLimit, ""},
		"code the config does not name": {`{"error":{"code":"1113","message":"Insufficient balance or no resource package. Please recharge."}}`, kindOther, "1113"},
		"policy limit":                  {`{"error":{"code":"1313","message":"Your account's current usage pattern does not comply with the Fair Usage Policy, and your request frequency has been limited."}}`, kindOther, "1313"},
		"not JSON":                      {`<html>429</html>`, kindOther, ""},
		"empty":                         {``, kindOther, ""},
	} {
		kind, code := cfg.classify([]byte(tc.body))
		if kind != tc.want || code != tc.code {
			t.Errorf("%s: classify = %s, %q; want %s, %q", name, kind, code, tc.want, tc.code)
		}
	}
}

func TestQuotaResetReadsTheZoneTheProviderPrintsWithout(t *testing.T) {
	cfg := testAdmission()
	cfg.QuotaResetUTCOffset = 8 * time.Hour
	answer := func(stamp string) []byte {
		return []byte(fmt.Sprintf(`{"error":{"code":"1308","message":"Usage limit reached for 5 hour. Your limit will reset at %s"}}`, stamp))
	}
	for name, tc := range map[string]struct {
		stamp string
		want  time.Time
	}{
		"bare stamp in the plan's zone": {"2026-11-15 23:51:01", time.Date(2026, 11, 15, 15, 51, 1, 0, time.UTC)},
		"ISO stamp in the plan's zone":  {"2026-11-15T23:51:01", time.Date(2026, 11, 15, 15, 51, 1, 0, time.UTC)},
		"stamp that names its zone":     {"2026-11-15T23:51:01+08:00", time.Date(2026, 11, 15, 15, 51, 1, 0, time.UTC)},
		"stamp in UTC":                  {"2026-11-15T15:51:01Z", time.Date(2026, 11, 15, 15, 51, 1, 0, time.UTC)},
	} {
		reset, ok := cfg.quotaReset(answer(tc.stamp))
		if !ok || !reset.Equal(tc.want) {
			t.Errorf("%s: quotaReset = %v, %t; want %v", name, reset, ok, tc.want)
		}
	}
	for _, body := range [][]byte{
		answer("tomorrow"),
		[]byte(`{"error":{"code":"1313","message":"no time in here"}}`),
		[]byte(`not json`),
	} {
		if _, ok := cfg.quotaReset(body); ok {
			t.Errorf("quotaReset(%s) parsed a reset", body)
		}
	}
}

func TestRetryAfterReadsWholeSeconds(t *testing.T) {
	for raw, want := range map[string]time.Duration{"2": 2 * time.Second, "0": 0, "": -1, "soon": -1, "-5": -1} {
		header := http.Header{}
		if raw != "" {
			header.Set("Retry-After", raw)
		}
		got, ok := retryAfter(header)
		if want < 0 {
			if ok {
				t.Errorf("Retry-After %q parsed as %v", raw, got)
			}
		} else if !ok || got != want {
			t.Errorf("Retry-After %q = %v, %t; want %v", raw, got, ok, want)
		}
	}
}

func TestPendingHonorsAShortRetryAfterAndDefersALongOneToTheClient(t *testing.T) {
	g, clock := clockedGate(testAdmission())
	header := http.Header{}
	header.Set("Retry-After", (maxHonoredRetryAfter + time.Second).String())
	call := g.open(*clock)
	call.rejected = 1
	if call.pause(context.Background(), header) {
		t.Fatalf("a Retry-After above %v was waited out", maxHonoredRetryAfter)
	}

	header.Set("Retry-After", "0")
	call = g.open(*clock)
	call.rejected = 1
	if !call.pause(context.Background(), header) {
		t.Fatal("a zero Retry-After was not honored")
	}

	expired := g.open(*clock.Add(-time.Hour))
	expired.rejected = 1
	if expired.pause(context.Background(), nil) {
		t.Fatal("a call past its budget was paused for a retry")
	}
}

func TestLoadConfigRefusesAnInvalidAdmissionAndNamesTheUpstream(t *testing.T) {
	dir := t.TempDir()
	keyFile := filepath.Join(dir, "crush.key")
	if err := os.WriteFile(keyFile, []byte("test-key-1"), 0o600); err != nil {
		t.Fatal(err)
	}
	for admission, wantErr := range map[string]string{
		`{"max_concurrency":3,"retryable_codes":["1302"]}`: "",
		`{"max_concurrency":0,"retryable_codes":["1302"]}`: "upstream zai: admission: max_concurrency",
		`{"max_concurrency":3}`:                            "upstream zai: admission: retryable_codes",
	} {
		body := `{"listen":"127.0.0.1:0","metrics_listen":"127.0.0.1:0","ledger_path":"` + filepath.Join(dir, "usage.jsonl") +
			`","clients":[{"name":"crush","key_file":"` + keyFile + `"}],"upstreams":[{"name":"zai","base_url":"https://example.test","admission":` + admission + `}]}`
		path := filepath.Join(dir, "config.json")
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		cfg, err := LoadConfig(path)
		switch {
		case wantErr == "" && err != nil:
			t.Errorf("admission %s: %v", admission, err)
		case wantErr == "" && cfg.Upstreams[0].Admission == nil:
			t.Errorf("admission %s: not kept on the upstream", admission)
		case wantErr != "" && (err == nil || !strings.Contains(err.Error(), wantErr)):
			t.Errorf("admission %s: error = %v, want one containing %q", admission, err, wantErr)
		}
	}
}
