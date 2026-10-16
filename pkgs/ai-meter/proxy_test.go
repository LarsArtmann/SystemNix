package main

import (
	"bufio"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// testStack wires a Proxy against a fake OpenAI-compatible upstream.
type testStack struct {
	upstream *httptest.Server
	proxy    *httptest.Server
	registry *Registry
	ledger   *Ledger
	cfg      *Config

	upstreamSawStreamOptions *bool
}

func newTestStack(t *testing.T, costs map[string]Cost) *testStack {
	t.Helper()
	dir := t.TempDir()

	stack := &testStack{upstreamSawStreamOptions: new(bool)}
	stack.upstream = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var payload map[string]any
		_ = json.Unmarshal(body, &payload)
		if opts, ok := payload["stream_options"].(map[string]any); ok && opts["include_usage"] == true {
			*stack.upstreamSawStreamOptions = true
		} else {
			*stack.upstreamSawStreamOptions = false
		}

		if stream, _ := payload["stream"].(bool); stream {
			w.Header().Set("Content-Type", "text/event-stream")
			flusher := w.(http.Flusher)
			for _, chunk := range []string{
				`data: {"choices":[{"delta":{"content":"Hel"}}]}`,
				`data: {"choices":[{"delta":{"content":"lo"}}]}`,
				`data: {"choices":[],"usage":{"prompt_tokens":12,"completion_tokens":4,"total_tokens":16,"prompt_tokens_details":{"cached_tokens":2}}}`,
				`data: [DONE]`,
			} {
				_, _ = io.WriteString(w, chunk+"\n\n")
				flusher.Flush()
			}
			return
		}

		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"id":"resp","model":"`+jsonString(payload["model"])+`","choices":[{"message":{"content":"ok"}}],"usage":{"prompt_tokens":100,"completion_tokens":50,"total_tokens":150,"prompt_tokens_details":{"cached_tokens":20}}}`)
	}))

	keyFile := filepath.Join(dir, "crush.key")
	if err := os.WriteFile(keyFile, []byte("test-key-1"), 0o600); err != nil {
		t.Fatal(err)
	}

	stack.cfg = &Config{
		Listen:            "127.0.0.1:0",
		MetricsListen:     "127.0.0.1:0",
		LedgerPath:        filepath.Join(dir, "usage.jsonl"),
		InjectStreamUsage: true,
		Clients:           []Client{{Name: "crush", KeyFile: keyFile, key: "test-key-1"}},
		Upstreams: []Upstream{
			{Name: "fake", BaseURL: stack.upstream.URL, APIKey: "unused"},
		},
		Costs: costs,
	}

	stack.registry = NewRegistry()
	var err error
	stack.ledger, err = OpenLedger(stack.cfg.LedgerPath, slog.Default())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = stack.ledger.Close() })

	proxy := NewProxy(stack.cfg, stack.registry, stack.ledger, slog.Default())
	stack.proxy = httptest.NewServer(proxy)
	t.Cleanup(stack.upstream.Close)
	t.Cleanup(stack.proxy.Close)
	return stack
}

func jsonString(v any) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

func (s *testStack) post(path, key, body string) *http.Response {
	t := &testing.T{}
	_ = t
	req, _ := http.NewRequest(http.MethodPost, s.proxy.URL+path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+key)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		panic(err)
	}
	return resp
}

func (s *testStack) ledgerLines(t *testing.T) []map[string]any {
	t.Helper()
	raw, err := os.ReadFile(s.cfg.LedgerPath)
	if err != nil {
		t.Fatal(err)
	}
	var entries []map[string]any
	for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
		if line == "" {
			continue
		}
		var entry map[string]any
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			t.Fatalf("bad ledger line %q: %v", line, err)
		}
		entries = append(entries, entry)
	}
	return entries
}

func TestProxyRejectsBadAuth(t *testing.T) {
	s := newTestStack(t, nil)

	resp := s.post("/v1/fake/chat/completions", "wrong-key", `{"model":"m"}`)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("want 401, got %d", resp.StatusCode)
	}
	if !strings.Contains(s.registry.Render(), "ai_meter_unauthorized_total 1") {
		t.Fatal("unauthorized metric not incremented")
	}
}

func TestProxyUnknownUpstreamAndRoute(t *testing.T) {
	s := newTestStack(t, nil)

	resp := s.post("/v1/nope/chat/completions", "test-key-1", `{"model":"m"}`)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("want 404, got %d", resp.StatusCode)
	}

	resp = s.post("/v1/fake", "test-key-1", `{"model":"m"}`)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("want 404 for route without subpath, got %d", resp.StatusCode)
	}
}

func TestProxyMetersNonStreamingChat(t *testing.T) {
	s := newTestStack(t, map[string]Cost{"m": {Input: 2, Output: 4, CachedInput: 0.5}})

	resp := s.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m","messages":[{"role":"user","content":"hi"}]}`)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if body["id"] != "resp" {
		t.Fatalf("upstream body not forwarded verbatim: %v", body)
	}

	out := s.registry.Render()
	for _, want := range []string{
		`ai_meter_requests_total{client="crush",code="200",model="m",upstream="fake"} 1`,
		`ai_meter_tokens_total{client="crush",kind="prompt",model="m",upstream="fake"} 100`,
		`ai_meter_tokens_total{client="crush",kind="completion",model="m",upstream="fake"} 50`,
		`ai_meter_tokens_total{client="crush",kind="cached",model="m",upstream="fake"} 20`,
		// cost: (100-20)*2/1e6 + 20*0.5/1e6 + 50*4/1e6 = 0.00037
		`ai_meter_cost_usd_total{client="crush",model="m",upstream="fake"} 0.00037`,
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("metrics missing %q\nexposition:\n%s", want, out)
		}
	}

	entries := s.ledgerLines(t)
	if len(entries) != 1 {
		t.Fatalf("want 1 ledger entry, got %d", len(entries))
	}
	if entries[0]["prompt_tokens"] != float64(100) || entries[0]["completion_tokens"] != float64(50) {
		t.Fatalf("ledger entry wrong: %v", entries[0])
	}
}

func TestProxyMetersStreamingChat(t *testing.T) {
	s := newTestStack(t, nil)

	resp := s.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m","stream":true,"messages":[]}`)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	scanner := bufio.NewScanner(resp.Body)
	var sawDone bool
	for scanner.Scan() {
		if scanner.Text() == "data: [DONE]" {
			sawDone = true
		}
	}
	if !sawDone {
		t.Fatal("stream not fully forwarded")
	}
	if !*s.upstreamSawStreamOptions {
		t.Fatal("proxy did not inject stream_options.include_usage")
	}

	out := s.registry.Render()
	for _, want := range []string{
		`ai_meter_tokens_total{client="crush",kind="prompt",model="m",upstream="fake"} 12`,
		`ai_meter_tokens_total{client="crush",kind="completion",model="m",upstream="fake"} 4`,
		`ai_meter_ttft_seconds_count{client="crush",model="m",upstream="fake"} 1`,
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("metrics missing %q\nexposition:\n%s", want, out)
		}
	}
}

func TestProxyRecordsUpstreamErrors(t *testing.T) {
	s := newTestStack(t, nil)
	// Repoint the upstream at a dead port.
	s.cfg.Upstreams[0].BaseURL = "http://127.0.0.1:1"

	resp := s.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m"}`)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadGateway {
		t.Fatalf("want 502, got %d", resp.StatusCode)
	}
	if !strings.Contains(s.registry.Render(), `code="502"`) {
		t.Fatal("502 not recorded")
	}
}

func TestProxyPassthroughModels(t *testing.T) {
	s := newTestStack(t, nil)

	req, _ := http.NewRequest(http.MethodGet, s.proxy.URL+"/v1/fake/models", nil)
	req.Header.Set("Authorization", "Bearer test-key-1")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	// The fake upstream's non-stream branch answers models with a JSON body.

	out := s.registry.Render()
	if !strings.Contains(out, `model="none"`) {
		t.Fatalf("passthrough not request-counted:\n%s", out)
	}
}

func TestAdminHandler(t *testing.T) {
	s := newTestStack(t, nil)
	handler := NewAdminHandler(s.registry)

	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/health", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "ok") {
		t.Fatalf("health: %d %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "# TYPE ai_meter_requests_total counter") {
		t.Fatalf("metrics: %d %s", rec.Code, rec.Body.String())
	}
}

func TestRegistryEscapesLabels(t *testing.T) {
	r := NewRegistry()
	r.Record(Record{Client: `we"ird`, Upstream: "u", Model: "m\nx", Status: 200})
	out := r.Render()
	if !strings.Contains(out, `client="we\"ird"`) || !strings.Contains(out, `model="m\nx"`) {
		t.Fatalf("labels not escaped:\n%s", out)
	}
}
