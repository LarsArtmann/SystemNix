package main

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

const chatBody = `{"model":"m","messages":[{"role":"user","content":"hi"}]}`

const okCompletion = `{"id":"resp","model":"m","choices":[{"message":{"content":"ok"}}],"usage":{"prompt_tokens":10,"completion_tokens":5,"total_tokens":15}}`

// rejection is an upstream's 429 in the shape z.ai answers: the business
// code sits in the error object.
func rejection(code, message string) string {
	return `{"error":{"code":"` + code + `","message":"` + message + `"}}`
}

func rejectWith(w http.ResponseWriter, code, message, retryAfter string) {
	w.Header().Set("Content-Type", "application/json")
	if retryAfter != "" {
		w.Header().Set("Retry-After", retryAfter)
	}
	w.WriteHeader(http.StatusTooManyRequests)
	_, _ = io.WriteString(w, rejection(code, message))
}

func chatWith(content string) string {
	return `{"model":"m","messages":[{"role":"user","content":"` + content + `"}]}`
}

// admission is one upstream's admission control for a test: nothing grows
// or times out unless the test says so.
func admission(maxConcurrency, maxWaitSeconds, maxRetries int) *AdmissionSettings {
	return &AdmissionSettings{
		MaxConcurrency:           maxConcurrency,
		MaxWaitSeconds:           maxWaitSeconds,
		MaxRetries:               maxRetries,
		GrowAfterSeconds:         3600,
		RetryableCodes:           []string{"1302", "1305"},
		QuotaCodes:               []string{"1308", "1310"},
		QuotaResetUTCOffsetHours: 8,
	}
}

// gatedStack is a testStack whose one upstream is gated and answers
// whatever answer says.
type gatedStack struct {
	*testStack
	gate *Gate
}

func newGatedStack(t *testing.T, settings *AdmissionSettings, answer http.HandlerFunc) *gatedStack {
	t.Helper()
	upstream := httptest.NewServer(answer)
	t.Cleanup(upstream.Close)

	dir := t.TempDir()
	keyFile := filepath.Join(dir, "crush.key")
	if err := os.WriteFile(keyFile, []byte("test-key-1"), 0o600); err != nil {
		t.Fatal(err)
	}
	ledger, err := OpenLedger(filepath.Join(dir, "usage.jsonl"), quietLogger())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ledger.Close() })

	stack := &gatedStack{}
	stack.testStack = &testStack{
		registry: NewRegistry(),
		ledger:   ledger,
		cfg: &Config{
			Listen:            "127.0.0.1:0",
			MetricsListen:     "127.0.0.1:0",
			LedgerPath:        filepath.Join(dir, "usage.jsonl"),
			InjectStreamUsage: true,
			Clients:           []Client{{Name: "crush", KeyFile: keyFile, key: "test-key-1"}},
			Upstreams: []Upstream{
				{Name: "fake", BaseURL: upstream.URL, APIKey: "unused", Admission: settings},
			},
		},
	}
	proxy := NewProxy(stack.cfg, stack.registry, stack.ledger, quietLogger())
	stack.gate = proxy.gates["fake"]
	if stack.gate == nil {
		t.Fatal("the upstream was not gated")
	}
	stack.proxy = httptest.NewServer(proxy)
	t.Cleanup(stack.proxy.Close)
	return stack
}

func (s *gatedStack) post(body string) *http.Response {
	return s.testStack.post("/v1/fake/chat/completions", "test-key-1", body)
}

// postAsync sends one call on its own goroutine; its answer ends up in
// responses.
func (s *gatedStack) postAsync(ctx context.Context, body string, responses chan<- *http.Response) {
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, s.proxy.URL+"/v1/fake/chat/completions", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-key-1")
	go func() { responses <- do(req) }()
}

// metric reads one series of the exposition.
func (s *gatedStack) metric(series string) (float64, bool) {
	for line := range strings.SplitSeq(s.registry.Render(), "\n") {
		if after, found := strings.CutPrefix(line, series+" "); found {
			value, err := strconv.ParseFloat(after, 64)
			return value, err == nil
		}
	}
	return 0, false
}

func (s *gatedStack) awaitMetric(t *testing.T, series string, want float64) {
	t.Helper()
	awaitFor(t, "metric "+series+" = "+strconv.FormatFloat(want, 'g', -1, 64), func() bool {
		value, found := s.metric(series)
		return found && value == want
	})
}

// ledgerEntries returns the ledger's lines, tolerating one being written.
func (s *gatedStack) ledgerEntries() []map[string]any {
	raw, _ := os.ReadFile(s.cfg.LedgerPath)
	var entries []map[string]any
	for line := range strings.SplitSeq(string(raw), "\n") {
		var entry map[string]any
		if json.Unmarshal([]byte(line), &entry) == nil {
			entries = append(entries, entry)
		}
	}
	return entries
}

func (s *gatedStack) awaitLedger(t *testing.T, n int) []map[string]any {
	t.Helper()
	awaitFor(t, "the ledger to hold its lines", func() bool { return len(s.ledgerEntries()) >= n })
	return s.ledgerEntries()
}

// hasField fails unless entry carries name with want (an int or a string),
// or, when want is nil, carries no such field.
func hasField(t *testing.T, entry map[string]any, name string, want any) {
	t.Helper()
	got, present := entry[name]
	if want == nil {
		if present {
			t.Errorf("ledger entry carries %s = %v, want it absent: %v", name, got, entry)
		}
		return
	}
	if number, ok := want.(int); ok {
		want = float64(number)
	}
	if got != want {
		t.Errorf("ledger entry %s = %v, want %v: %v", name, got, want, entry)
	}
}

func responseBody(t *testing.T, resp *http.Response) string {
	t.Helper()
	defer func() { _ = resp.Body.Close() }()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return string(body)
}

func TestProxyAdmissionQueuesCallsWithinTheAllowance(t *testing.T) {
	started := make(chan struct{}, 6)
	release := make(chan struct{})
	var inflight, peak atomic.Int32
	s := newGatedStack(t, admission(2, 30, 6), func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.ReadAll(r.Body)
		if n := inflight.Add(1); n > peak.Load() {
			peak.Store(n)
		}
		started <- struct{}{}
		<-release
		inflight.Add(-1)
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, okCompletion)
	})

	responses := make(chan *http.Response, 6)
	for range 6 {
		s.postAsync(context.Background(), chatBody, responses)
	}
	for range 2 {
		<-started
	}
	select {
	case <-started:
		t.Fatal("a third call reached the upstream at an allowance of 2")
	case <-time.After(100 * time.Millisecond):
	}
	for series, want := range map[string]float64{
		`ai_meter_admission_inflight{upstream="fake"}`: 2,
		`ai_meter_admission_waiting{upstream="fake"}`:  4,
		`ai_meter_admission_limit{upstream="fake"}`:    2,
	} {
		s.awaitMetric(t, series, want)
	}

	close(release)
	for range 4 {
		<-started
	}
	for range 6 {
		resp := <-responses
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("want 200, got %d: %s", resp.StatusCode, responseBody(t, resp))
		}
		_ = resp.Body.Close()
	}
	if got := peak.Load(); got != 2 {
		t.Fatalf("upstream peak = %d, want the allowance of 2", got)
	}

	waited := 0
	for _, entry := range s.awaitLedger(t, 6) {
		hasField(t, entry, "status", 200)
		hasField(t, entry, "attempts", nil)
		hasField(t, entry, "admission", nil)
		if queueMS, _ := entry["queue_ms"].(float64); queueMS > 0 {
			waited++
		}
	}
	if waited != 4 {
		t.Fatalf("%d of 6 calls were recorded as having waited, want the 4 that queued", waited)
	}
	s.awaitMetric(t, `ai_meter_admission_wait_seconds_count{upstream="fake"}`, 4)
}

func TestProxyAdmissionAbsorbsARateLimitRejection(t *testing.T) {
	var calls atomic.Int32
	s := newGatedStack(t, admission(3, 30, 6), func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.ReadAll(r.Body)
		if calls.Add(1) == 1 {
			rejectWith(w, "1302", "Rate limit reached for requests", "")
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("X-Answer", "second")
		_, _ = io.WriteString(w, okCompletion)
	})
	before := s.gate.allowance()

	resp := s.post(chatBody)
	if body := responseBody(t, resp); resp.StatusCode != http.StatusOK || resp.Header.Get("X-Answer") != "second" || body != okCompletion {
		t.Fatalf("the rejection reached the client: %d %q", resp.StatusCode, body)
	}
	if got := calls.Load(); got != 2 {
		t.Fatalf("upstream answered %d times, want 2", got)
	}

	entries := s.awaitLedger(t, 1)
	hasField(t, entries[0], "status", 200)
	hasField(t, entries[0], "attempts", 2)
	hasField(t, entries[0], "admission", "absorbed")
	hasField(t, entries[0], "upstream_code", nil)
	s.awaitMetric(t, `ai_meter_upstream_rejections_total{upstream="fake",model="m",code="1302",kind="rate_limit"}`, 1)
	s.awaitMetric(t, `ai_meter_admission_outcomes_total{client="crush",upstream="fake",model="m",outcome="absorbed"}`, 1)
	if got := s.gate.allowance(); got != before-1 {
		t.Fatalf("allowance = %d after one rejection, want %d", got, before-1)
	}
}

func TestProxyAdmissionGivesUpAfterTheLastRetry(t *testing.T) {
	var calls atomic.Int32
	s := newGatedStack(t, admission(3, 30, 2), func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.ReadAll(r.Body)
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("X-Attempt", strconv.FormatInt(int64(calls.Add(1)), 10))
		w.WriteHeader(http.StatusTooManyRequests)
		_, _ = io.WriteString(w, rejection("1302", "Rate limit reached for requests"))
	})
	before := s.gate.allowance()

	resp := s.post(chatBody)
	body := responseBody(t, resp)
	if resp.StatusCode != http.StatusTooManyRequests || resp.Header.Get("X-Attempt") != "3" || body != rejection("1302", "Rate limit reached for requests") {
		t.Fatalf("want the third rejection as it came, got %d %q", resp.StatusCode, body)
	}
	if got := calls.Load(); got != 3 {
		t.Fatalf("upstream answered %d times, want 3 (the call and 2 retries)", got)
	}

	entries := s.awaitLedger(t, 1)
	hasField(t, entries[0], "status", 429)
	hasField(t, entries[0], "attempts", 3)
	hasField(t, entries[0], "admission", "gave_up")
	hasField(t, entries[0], "upstream_code", "1302")
	hasField(t, entries[0], "ttft_ms", -1)
	s.awaitMetric(t, `ai_meter_upstream_rejections_total{upstream="fake",model="m",code="1302",kind="rate_limit"}`, 3)
	s.awaitMetric(t, `ai_meter_admission_outcomes_total{client="crush",upstream="fake",model="m",outcome="gave_up"}`, 1)
	if got := s.gate.allowance(); got >= before {
		t.Fatalf("allowance = %d after three rejections, want below %d", got, before)
	}
}

func TestProxyUngatedRateLimitPassesThrough(t *testing.T) {
	var calls atomic.Int32
	rejecting := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		rejectWith(w, "1302", "Rate limit reached for requests", "")
	}))
	t.Cleanup(rejecting.Close)
	s := newTestStack(t, nil)
	s.cfg.Upstreams[0].BaseURL = rejecting.URL

	resp := s.post("/v1/fake/chat/completions", "test-key-1", chatBody)
	if body := responseBody(t, resp); resp.StatusCode != http.StatusTooManyRequests || body != rejection("1302", "Rate limit reached for requests") {
		t.Fatalf("want the rejection once, got %d %q", resp.StatusCode, body)
	}
	if got := calls.Load(); got != 1 {
		t.Fatalf("an ungated upstream was asked %d times, want once", got)
	}

	entries := s.ledgerLines(t)
	hasField(t, entries[0], "status", 429)
	hasField(t, entries[0], "upstream_code", "1302")
	hasField(t, entries[0], "attempts", nil)
	hasField(t, entries[0], "admission", nil)
	if out := s.registry.Render(); strings.Contains(out, "ai_meter_admission_inflight{") {
		t.Fatalf("an ungated upstream has admission series:\n%s", out)
	}
}

func TestProxyAdmissionHonorsAShortRetryAfterAndLeavesALongOneToTheClient(t *testing.T) {
	for name, tc := range map[string]struct {
		retryAfter string
		wantStatus int
		wantWait   time.Duration
		wantTries  int
		wantEnd    string
	}{
		"one second is waited out":            {"1", http.StatusOK, time.Second, 2, "absorbed"},
		"eleven seconds belong to the client": {"11", http.StatusTooManyRequests, 0, 1, "gave_up"},
	} {
		t.Run(name, func(t *testing.T) {
			var calls atomic.Int32
			s := newGatedStack(t, admission(2, 30, 6), func(w http.ResponseWriter, r *http.Request) {
				_, _ = io.ReadAll(r.Body)
				if calls.Add(1) == 1 {
					rejectWith(w, "1302", "Rate limit reached for requests", tc.retryAfter)
					return
				}
				w.Header().Set("Content-Type", "application/json")
				_, _ = io.WriteString(w, okCompletion)
			})

			sent := time.Now()
			resp := s.post(chatBody)
			body := responseBody(t, resp)
			if elapsed := time.Since(sent); elapsed < tc.wantWait {
				t.Fatalf("the proxy answered after %v, want at least %v", elapsed, tc.wantWait)
			}
			wantBody := okCompletion
			if tc.wantStatus == http.StatusTooManyRequests {
				wantBody = rejection("1302", "Rate limit reached for requests")
				if got := resp.Header.Get("Retry-After"); got != "11" {
					t.Fatalf("Retry-After = %q, want the upstream's 11 passed on", got)
				}
			}
			if resp.StatusCode != tc.wantStatus || body != wantBody {
				t.Fatalf("want %d, got %d %q", tc.wantStatus, resp.StatusCode, body)
			}
			if got := calls.Load(); int(got) != tc.wantTries {
				t.Fatalf("upstream answered %d times, want %d", got, tc.wantTries)
			}

			entries := s.awaitLedger(t, 1)
			hasField(t, entries[0], "status", tc.wantStatus)
			// One attempt is the ledger's default: absent means one.
			if tc.wantTries == 1 {
				hasField(t, entries[0], "attempts", nil)
			} else {
				hasField(t, entries[0], "attempts", tc.wantTries)
			}
			hasField(t, entries[0], "admission", tc.wantEnd)
		})
	}
}

func TestProxyStreamedErrorHasNoTimeToFirstToken(t *testing.T) {
	failing := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = io.WriteString(w, `{"error":{"code":"500","message":"boom"}}`)
	}))
	t.Cleanup(failing.Close)
	s := newTestStack(t, nil)
	s.cfg.Upstreams[0].BaseURL = failing.URL

	resp := s.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m","stream":true,"messages":[]}`)
	if resp.StatusCode != http.StatusInternalServerError {
		t.Fatalf("want 500, got %d: %s", resp.StatusCode, responseBody(t, resp))
	}
	_ = resp.Body.Close()

	entries := s.ledgerLines(t)
	hasField(t, entries[0], "status", 500)
	hasField(t, entries[0], "upstream_code", "500")
	hasField(t, entries[0], "ttft_ms", -1)
	if out := s.registry.Render(); strings.Contains(out, `ai_meter_ttft_seconds_count{client="crush",upstream="fake",model="m"} 1`) {
		t.Fatalf("an error answer became a time-to-first-token sample:\n%s", out)
	}
}

func TestProxyAdmissionSendsBackACallThatOutlivesItsWaitBudget(t *testing.T) {
	release := make(chan struct{})
	var calls atomic.Int32
	s := newGatedStack(t, admission(1, 1, 6), func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.ReadAll(r.Body)
		calls.Add(1)
		<-release
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, okCompletion)
	})

	responses := make(chan *http.Response, 2)
	s.postAsync(context.Background(), chatBody, responses)
	awaitFor(t, "the first call to hold the slot", func() bool { return calls.Load() == 1 })
	sent := time.Now()
	s.postAsync(context.Background(), chatBody, responses)
	resp := <-responses
	body := responseBody(t, resp)
	elapsed := time.Since(sent)
	if elapsed < time.Second || elapsed > 3*time.Second {
		t.Fatalf("the sent-back call was answered after %v, want about its budget of 1s", elapsed)
	}
	if resp.StatusCode != http.StatusTooManyRequests || resp.Header.Get("Retry-After") != "1" {
		t.Fatalf("want 429 with Retry-After 1, got %d with %q", resp.StatusCode, resp.Header.Get("Retry-After"))
	}
	var answer struct {
		Error struct {
			Message string `json:"message"`
			Type    string `json:"type"`
		} `json:"error"`
	}
	if err := json.Unmarshal([]byte(body), &answer); err != nil || answer.Error.Type != "ai_meter_error" || !strings.Contains(answer.Error.Message, "retry") {
		t.Fatalf("the sent-back call's body does not tell the client to retry: %q", body)
	}
	if got := calls.Load(); got != 1 {
		t.Fatalf("the upstream was asked %d times, want only by the call that holds the slot", got)
	}

	entries := s.awaitLedger(t, 1)
	hasField(t, entries[0], "status", 429)
	hasField(t, entries[0], "attempts", 0)
	hasField(t, entries[0], "admission", "timeout")
	if queueMS, _ := entries[0]["queue_ms"].(float64); queueMS < 900 {
		t.Errorf("a call that waited out its budget records queue_ms = %v", entries[0]["queue_ms"])
	}
	s.awaitMetric(t, `ai_meter_admission_outcomes_total{client="crush",upstream="fake",model="m",outcome="timeout"}`, 1)

	close(release)
	if resp := <-responses; resp.StatusCode != http.StatusOK {
		t.Fatalf("the call that held the slot: want 200, got %d", resp.StatusCode)
	} else {
		_ = resp.Body.Close()
	}
}

func TestProxyAdmissionBudgetAlsoEndsBetweenAttempts(t *testing.T) {
	var calls atomic.Int32
	s := newGatedStack(t, admission(2, 1, 6), func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		rejectWith(w, "1302", "Rate limit reached for requests", "9")
	})
	before := s.gate.allowance()

	sent := time.Now()
	resp := s.post(chatBody)
	body := responseBody(t, resp)
	if elapsed := time.Since(sent); elapsed >= time.Second {
		t.Fatalf("the proxy waited %v for a delay longer than the call's budget", elapsed)
	}
	if resp.StatusCode != http.StatusTooManyRequests || body != rejection("1302", "Rate limit reached for requests") {
		t.Fatalf("want the upstream's rejection back, got %d %q", resp.StatusCode, body)
	}
	if got := resp.Header.Get("Retry-After"); got != "1" {
		t.Fatalf("Retry-After = %q, want 1 so the client re-enters with a new budget", got)
	}
	if got := calls.Load(); got != 1 {
		t.Fatalf("upstream answered %d times, want 1", got)
	}

	entries := s.awaitLedger(t, 1)
	hasField(t, entries[0], "status", 429)
	// One attempt is the ledger's default: absent means one.
	hasField(t, entries[0], "attempts", nil)
	hasField(t, entries[0], "admission", "timeout")
	hasField(t, entries[0], "upstream_code", "1302")
	if got := s.gate.allowance(); got != before-1 {
		t.Fatalf("allowance = %d, want %d", got, before-1)
	}
}

func TestProxyAdmissionOpensACircuitWhileTheQuotaIsSpent(t *testing.T) {
	var calls atomic.Int32
	stamp := time.Now().Add(time.Hour).UTC().Add(8 * time.Hour).Format("2006-01-02 15:04:05")
	body := rejection("1308", "Usage limit reached for 5 hour. Your limit will reset at "+stamp)
	s := newGatedStack(t, admission(3, 30, 6), func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		rejectWith(w, "1308", "Usage limit reached for 5 hour. Your limit will reset at "+stamp, "")
	})

	first := s.post(chatBody)
	if got := responseBody(t, first); first.StatusCode != http.StatusTooManyRequests || got != body || first.Header.Get("Retry-After") != "" {
		t.Fatalf("the first quota answer must come back as it came: %d %q", first.StatusCode, got)
	}

	second := s.post(chatBody)
	got := responseBody(t, second)
	seconds, err := strconv.Atoi(second.Header.Get("Retry-After"))
	if second.StatusCode != http.StatusTooManyRequests || got != body || err != nil || seconds < 3598 || seconds > 3602 {
		t.Fatalf("the spent quota must be answered from the circuit with the wait to the reset: %d Retry-After %q", second.StatusCode, second.Header.Get("Retry-After"))
	}
	if n := calls.Load(); n != 1 {
		t.Fatalf("the upstream was asked %d times while its quota is spent, want once", n)
	}

	entries := s.awaitLedger(t, 2)
	hasField(t, entries[0], "status", 429)
	hasField(t, entries[0], "upstream_code", "1308")
	hasField(t, entries[0], "admission", nil)
	hasField(t, entries[1], "status", 429)
	hasField(t, entries[1], "upstream_code", "1308")
	hasField(t, entries[1], "admission", "circuit")
	hasField(t, entries[1], "attempts", 0)
	s.awaitMetric(t, `ai_meter_quota_exhausted{upstream="fake"}`, 1)
	s.awaitMetric(t, `ai_meter_upstream_rejections_total{upstream="fake",model="m",code="1308",kind="quota"}`, 1)
}

func TestProxyAdmissionRecordsACallWhoseClientLeavesTheQueue(t *testing.T) {
	release := make(chan struct{})
	var calls atomic.Int32
	s := newGatedStack(t, admission(1, 30, 6), func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.ReadAll(r.Body)
		calls.Add(1)
		<-release
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, okCompletion)
	})

	responses := make(chan *http.Response, 3)
	s.postAsync(context.Background(), chatBody, responses)
	awaitFor(t, "the first call to hold the slot", func() bool { return calls.Load() == 1 })
	ctx, cancel := context.WithCancel(context.Background())
	s.postAsync(ctx, chatBody, responses)
	s.awaitMetric(t, `ai_meter_admission_waiting{upstream="fake"}`, 1)
	cancel()

	entries := s.awaitLedger(t, 1)
	hasField(t, entries[0], "status", 499)
	hasField(t, entries[0], "admission", "cancelled")
	hasField(t, entries[0], "attempts", 0)

	close(release)
	// The client that left gets a transport error from its own library; the
	// call that held the slot gets its answer.
	statuses := 0
	for range 2 {
		resp := <-responses
		statuses += resp.StatusCode
		_ = resp.Body.Close()
	}
	if statuses != http.StatusOK+http.StatusBadGateway {
		t.Fatalf("after the client left: statuses sum to %d, want one 200 and one transport error", statuses)
	}

	// Nothing is left behind: the slot the leaving call never took is free.
	awaitFor(t, "the gate to drain", func() bool {
		inflight, waiting := s.gate.snapshot()
		return inflight == 0 && waiting == 0
	})
	if resp := s.post(chatBody); resp.StatusCode != http.StatusOK {
		t.Fatalf("a call after everything left: want 200, got %d", resp.StatusCode)
	} else {
		_ = resp.Body.Close()
	}
	if got := calls.Load(); got != 2 {
		t.Fatalf("the upstream was asked %d times, want 2", got)
	}
}

func TestProxyAdmissionLeavesLimitsOnlyTheClientCanActOnAlone(t *testing.T) {
	var calls atomic.Int32
	s := newGatedStack(t, admission(3, 30, 6), func(w http.ResponseWriter, r *http.Request) {
		n := calls.Add(1)
		if n == 1 {
			rejectWith(w, "1113", "Insufficient balance or no resource package. Please recharge.", "")
			return
		}
		if n == 2 {
			rejectWith(w, "1313", "Your account's current usage pattern does not comply with the Fair Usage Policy, and your request frequency has been limited.", "")
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, okCompletion)
	})
	before := s.gate.allowance()

	for _, want := range []struct{ code, body string }{
		{"1113", rejection("1113", "Insufficient balance or no resource package. Please recharge.")},
		{"1313", rejection("1313", "Your account's current usage pattern does not comply with the Fair Usage Policy, and your request frequency has been limited.")},
	} {
		resp := s.post(chatBody)
		if got := responseBody(t, resp); resp.StatusCode != http.StatusTooManyRequests || got != want.body {
			t.Fatalf("code %s: want the answer as it came, got %d %q", want.code, resp.StatusCode, got)
		}
	}

	entries := s.awaitLedger(t, 2)
	for i, code := range []string{"1113", "1313"} {
		hasField(t, entries[i], "status", 429)
		hasField(t, entries[i], "upstream_code", code)
		hasField(t, entries[i], "attempts", nil)
		hasField(t, entries[i], "admission", nil)
	}
	if got := calls.Load(); got != 2 || s.gate.allowance() != before {
		t.Fatalf("upstream asked %d times at allowance %d, want 2 at %d", got, s.gate.allowance(), before)
	}
	if strings.Contains(s.registry.Render(), "ai_meter_upstream_rejections_total{") {
		t.Fatalf("a limit only the client can act on was counted against the admission:\n%s", s.registry.Render())
	}
}

func TestProxyAdmissionACallTheClientSendsAgainKeepsItsPlace(t *testing.T) {
	release := make(chan struct{})
	var mu sync.Mutex
	var order []string
	var arrived atomic.Int32
	s := newGatedStack(t, admission(1, 1, 6), func(w http.ResponseWriter, r *http.Request) {
		var payload struct {
			Messages []struct {
				Content string `json:"content"`
			} `json:"messages"`
		}
		_ = json.NewDecoder(r.Body).Decode(&payload)
		if len(payload.Messages) > 0 {
			arrived.Add(1)
		}
		if len(payload.Messages) > 0 && payload.Messages[0].Content == "hold" {
			<-release
		} else if len(payload.Messages) > 0 {
			mu.Lock()
			order = append(order, payload.Messages[0].Content)
			mu.Unlock()
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, okCompletion)
	})

	responses := make(chan *http.Response, 4)
	s.postAsync(context.Background(), chatWith("hold"), responses)
	awaitFor(t, "the first call to reach the upstream", func() bool { return arrived.Load() == 1 })

	// X arrives, outlives its budget of one second, and is sent back.
	s.postAsync(context.Background(), chatWith("X"), responses)
	back := <-responses
	if back.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("X: want 429 after its budget, got %d", back.StatusCode)
	}
	_ = back.Body.Close()

	// Y arrives after X was sent back; then the client sends X again.
	s.postAsync(context.Background(), chatWith("Y"), responses)
	s.awaitMetric(t, `ai_meter_admission_waiting{upstream="fake"}`, 1)
	s.postAsync(context.Background(), chatWith("X"), responses)
	s.awaitMetric(t, `ai_meter_admission_waiting{upstream="fake"}`, 2)

	close(release)
	for range 3 {
		if resp := <-responses; resp.StatusCode != http.StatusOK {
			t.Fatalf("want 200, got %d", resp.StatusCode)
		} else {
			_ = resp.Body.Close()
		}
	}
	awaitFor(t, "the upstream to see both calls", func() bool {
		mu.Lock()
		defer mu.Unlock()
		return len(order) == 2
	})
	mu.Lock()
	got := slices.Clone(order)
	mu.Unlock()
	if !slices.Equal(got, []string{"X", "Y"}) {
		t.Fatalf("the upstream saw %v, want X first: it came before Y, the first time", got)
	}
	s.awaitMetric(t, `ai_meter_admission_kept_arrival_total{upstream="fake"}`, 1)
}
