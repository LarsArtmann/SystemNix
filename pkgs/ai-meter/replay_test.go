package main

import (
	"io"
	"log/slog"
	"math"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// restartStack brings a second proxy up over the stack's ledger file, the
// way a service restart does: a fresh registry, seeded from the ledger at the
// given prices, then serving traffic.
func restartStack(t *testing.T, s *testStack, costs map[string]Cost) *testStack {
	t.Helper()
	cfg := *s.cfg
	cfg.Costs = costs

	registry := NewRegistry()
	ledger, err := OpenLedger(cfg.LedgerPath, slog.Default())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ledger.Close() })
	// The same two calls run() makes, minus the goroutine.
	registry.BeginCostReplay()
	seedCostCounter(&cfg, ledger, registry, slog.Default())

	restarted := &testStack{upstream: s.upstream, cfg: &cfg, registry: registry, ledger: ledger}
	restarted.proxy = httptest.NewServer(NewProxy(&cfg, registry, ledger, slog.Default()))
	t.Cleanup(restarted.proxy.Close)
	return restarted
}

// counterValue reads one model's series out of a rendered exposition.
func counterValue(t *testing.T, exposition, metric, model string) float64 {
	t.Helper()
	for line := range strings.SplitSeq(exposition, "\n") {
		if strings.HasPrefix(line, metric+"{") && strings.Contains(line, `model="`+model+`"`) {
			value, err := strconv.ParseFloat(line[strings.LastIndexByte(line, ' ')+1:], 64)
			if err != nil {
				t.Fatalf("parse %q: %v", line, err)
			}
			return value
		}
	}
	t.Fatalf("%s has no series for model %q:\n%s", metric, model, exposition)
	return 0
}

func assertCost(t *testing.T, exposition, model string, want float64) {
	t.Helper()
	if got := counterValue(t, exposition, "ai_meter_cost_usd_total", model); math.Abs(got-want) > 1e-12 {
		t.Fatalf("cost of model %q = %v, want %v\nexposition:\n%s", model, got, want, exposition)
	}
}

// The scenario this package exists for: a model is used before its price is
// published, the price lands, and every earlier call is priced by nothing
// more than the restart that ships the row.
func TestReplayCostsRestatesHistoryWhenAPriceLands(t *testing.T) {
	price := map[string]Cost{"m": {Input: 2, Output: 4, CachedInput: 0.5}}

	s := newTestStack(t, nil)
	for range 2 {
		resp := s.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m"}`)
		_ = resp.Body.Close()
	}
	assertCost(t, s.registry.Render(), "m", 0)

	for _, entry := range s.ledgerLines(t) {
		if _, stored := entry["cost_usd"]; stored {
			t.Fatalf("the ledger stores a cost, which goes stale when the price table changes: %v", entry)
		}
	}

	restarted := restartStack(t, s, price)
	assertCost(t, restarted.registry.Render(), "m", 2*0.00037)

	resp := restarted.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m"}`)
	_ = resp.Body.Close()
	assertCost(t, restarted.registry.Render(), "m", 3*0.00037)

	// Another restart at the same prices must not count anything twice.
	again := restartStack(t, s, price)
	assertCost(t, again.registry.Render(), "m", 3*0.00037)

	// A price that is withdrawn restates downward just the same.
	assertCost(t, restartStack(t, s, nil).registry.Render(), "m", 0)
}

// Re-baselining the other families would read as one enormous spike in every
// rate() panel and ratio alert that consumes them; they keep their
// restart-reset semantics.
func TestReplayCostsRestoresTheCostFamilyOnly(t *testing.T) {
	s := newTestStack(t, nil)
	resp := s.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m"}`)
	_ = resp.Body.Close()

	out := restartStack(t, s, map[string]Cost{"m": {Input: 2}}).registry.Render()
	if strings.Contains(out, "ai_meter_requests_total{") || strings.Contains(out, "ai_meter_tokens_total{") {
		t.Fatalf("a restart-reset family was restored from the ledger:\n%s", out)
	}
	if strings.Contains(out, "ai_meter_metering_errors_total 1") {
		t.Fatalf("replaying a healthy ledger counted a metering error:\n%s", out)
	}
}

func TestReplayCostsSkipsLinesThatAreNotRecordedCalls(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "usage.jsonl")
	// A torn write, foreign content, a JSON null and a blank line, plus an
	// old-format line (ledgers written before cost moved out of them carry
	// a stale cost_usd, which must be ignored rather than trusted).
	content := `{"time":"t1","client":"crush","upstream":"zai","model":"glm-5.4","status":200,"prompt_tokens":100,"completion_tokens":50,"cached_tokens":20,"total_tokens":150}
{not json
{"time":"t2","client":"crush","upstream":"zai","model":"glm-5.4","prompt_tok
null

{"time":"t3","client":"crush","upstream":"zai","model":"zai/glm-5.3","status":200,"prompt_tokens":100,"completion_tokens":50,"cached_tokens":20,"total_tokens":150,"cost_usd":0}`
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}

	cfg := &Config{Costs: map[string]Cost{
		"glm-5.4": {Input: 2, Output: 4, CachedInput: 0.5},
		"glm-5.3": {Input: 1, Output: 4, CachedInput: 0.5},
	}}
	registry := NewRegistry()
	ledger, err := OpenLedger(path, slog.Default())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ledger.Close() })
	seedCostCounter(cfg, ledger, registry, slog.Default())

	summary, err := ledger.ReplayCosts(cfg, NewRegistry())
	if err != nil {
		t.Fatalf("replay: %v", err)
	}
	if summary.Calls != 2 || summary.Skipped != 3 {
		t.Fatalf("replayed %d calls and skipped %d lines, want 2 and 3", summary.Calls, summary.Skipped)
	}
	if math.Abs(summary.CostUSD-(0.00037+0.00029)) > 1e-12 {
		t.Fatalf("replayed cost = %v, want %v", summary.CostUSD, 0.00037+0.00029)
	}

	out := registry.Render()
	assertCost(t, out, "glm-5.4", 0.00037)
	// The series keeps the requested model name; only the lookup strips it.
	assertCost(t, out, "zai/glm-5.3", 0.00029)
	if !strings.Contains(out, "ai_meter_metering_errors_total 3") {
		t.Fatalf("skipped lines must surface as metering errors:\n%s", out)
	}
}

// The replay reads only what the ledger held when it began: a call recorded
// after that moment is folded in live by the request path, and reading it a
// second time here would count it twice.
// The replay runs while the proxy serves; a half-replayed total must never
// be scraped as if it were the whole spend.
func TestCostCounterIsOnlyScrapedWhole(t *testing.T) {
	registry := NewRegistry()
	registry.BeginCostReplay()
	registry.RestoreCost(Record{Client: "crush", Upstream: "zai", Model: "m", CostUSD: 1})
	if strings.Contains(registry.Render(), "ai_meter_cost_usd_total") {
		t.Fatalf("a half-replayed cost counter was rendered:\n%s", registry.Render())
	}
	// A call that lands meanwhile is added on top, not lost.
	registry.Record(Record{Client: "crush", Upstream: "zai", Model: "m", Status: 200, CostUSD: 0.5})
	registry.EndCostReplay()
	assertCost(t, registry.Render(), "m", 1.5)
}

func TestReplayCostsReadsOnlyTheLedgerAsItStood(t *testing.T) {
	call := `{"time":"t","client":"crush","upstream":"zai","model":"m","status":200,"prompt_tokens":100,"completion_tokens":50,"cached_tokens":20}` + "\n"
	ledger := call + call + call
	// The replay began once two calls were recorded; the third landed after.
	summary, err := replayCosts(io.LimitReader(strings.NewReader(ledger), int64(len(call)*2)), &Config{}, NewRegistry())
	if err != nil {
		t.Fatalf("replay: %v", err)
	}
	if summary.Calls != 2 {
		t.Fatalf("replayed %d calls, want the 2 the ledger held when the replay began", summary.Calls)
	}
}

func TestOpenLedgerTerminatesATornTailLine(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "usage.jsonl")
	if err := os.WriteFile(path, []byte(`{"time":"t1","client":"crush"`), 0o600); err != nil {
		t.Fatal(err)
	}

	ledger, err := OpenLedger(path, slog.Default())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ledger.Close() })
	if err := ledger.Append(Record{Client: "crush", Upstream: "zai", Model: "m", Status: 200}); err != nil {
		t.Fatal(err)
	}

	// Exactly the torn entry is lost; the next one starts on its own line.
	// It was recorded after the open, so a FRESH open is what replays it.
	reopened, err := OpenLedger(path, slog.Default())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = reopened.Close() })
	summary, err := reopened.ReplayCosts(&Config{}, NewRegistry())
	if err != nil {
		t.Fatalf("replay: %v", err)
	}
	if summary.Calls != 1 || summary.Skipped != 1 {
		t.Fatalf("replayed %d calls and skipped %d lines, want 1 and 1", summary.Calls, summary.Skipped)
	}
}

// A call that is recorded after the ledger was opened is folded in live by
// the request path. The replay must leave it alone, or it is paid for twice.
func TestReplayCostsLeavesCallsRecordedAfterTheOpenAlone(t *testing.T) {
	price := map[string]Cost{"m": {Input: 2}}

	s := newTestStack(t, price)
	for range 2 {
		resp := s.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m"}`)
		_ = resp.Body.Close()
	}

	// The stack's ledger was opened before either call: its replay sees
	// nothing, and the calls exist exactly once, in the live counter.
	summary, err := s.ledger.ReplayCosts(&Config{Costs: price}, NewRegistry())
	if err != nil {
		t.Fatalf("replay: %v", err)
	}
	if summary.Calls != 0 {
		t.Fatalf("a ledger replayed %d calls that were recorded after it was opened", summary.Calls)
	}

	// The next process finds both, and nothing more.
	assertCost(t, restartStack(t, s, price).registry.Render(), "m", 2*EstimateCost(100, 20, 50, Cost{Input: 2}))
}

func TestOpenLedgerLeavesATerminatedFileAlone(t *testing.T) {
	path := filepath.Join(t.TempDir(), "usage.jsonl")
	content := `{"time":"t1","client":"crush"}
`
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	ledger, err := OpenLedger(path, slog.Default())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ledger.Close() })
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Size() != int64(len(content)) {
		t.Fatalf("a terminated ledger grew by %d byte(s) on open", info.Size()-int64(len(content)))
	}
}

// A ledger that cannot be read must cost the cost counter its history, never
// the proxy its start: every routed call depends on it.
func TestSeedCostCounterSurvivesAnUnreadableLedger(t *testing.T) {
	registry := NewRegistry()
	seedCostCounter(&Config{}, &Ledger{path: filepath.Join(t.TempDir(), "missing.jsonl")}, registry, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if !strings.Contains(registry.Render(), "ai_meter_metering_errors_total 1") {
		t.Fatalf("an unreadable ledger was not counted as a metering error:\n%s", registry.Render())
	}
}
