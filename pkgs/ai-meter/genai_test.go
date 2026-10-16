package main

import (
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

func TestParseGenAIPath(t *testing.T) {
	cases := []struct {
		path   string
		model  string
		stream bool
		ok     bool
	}{
		{"v1beta/models/gemini-2.5-flash:streamGenerateContent", "gemini-2.5-flash", true, true},
		{"v1/models/gemini-3-pro:generateContent", "gemini-3-pro", false, true},
		{"v1alpha/models/gemini-2.0-flash-lite:streamGenerateContent", "gemini-2.0-flash-lite", true, true},
		{"v1beta/models/gemini-2.5-flash:countTokens", "", false, false},
		{"v1beta/models", "", false, false},
		{"chat/completions", "", false, false},
		{"v1beta/models/a/b:generateContent", "", false, false},
	}
	for _, tc := range cases {
		got, ok := ParseGenAIPath(tc.path)
		if ok != tc.ok {
			t.Fatalf("ParseGenAIPath(%q): ok = %v, want %v", tc.path, ok, tc.ok)
		}
		if ok && (got.Model != tc.model || got.Stream != tc.stream) {
			t.Fatalf("ParseGenAIPath(%q) = %+v, want model %q stream %v", tc.path, got, tc.model, tc.stream)
		}
	}
}

func TestExtractGenAIUsage(t *testing.T) {
	buffered := []byte(`{"candidates":[{"content":{"parts":[{"text":"ok"}]}}],"usageMetadata":{"promptTokenCount":9,"candidatesTokenCount":2,"thoughtsTokenCount":3,"cachedContentTokenCount":4,"totalTokenCount":14}}`)
	u, ok := ExtractGenAIUsageJSON(buffered)
	if !ok {
		t.Fatal("buffered usageMetadata not found")
	}
	if u.PromptTokens != 9 || u.CompletionTokens != 5 || u.CachedTokens != 4 || u.TotalTokens != 14 {
		t.Fatalf("buffered usage = %+v", u)
	}

	sse := []byte(`{"candidates":[{"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":7,"candidatesTokenCount":1,"totalTokenCount":8}}`)
	u, ok = ExtractGenAIUsageSSE(sse)
	if !ok {
		t.Fatal("SSE usageMetadata not found")
	}
	if u.PromptTokens != 7 || u.CompletionTokens != 1 || u.TotalTokens != 8 {
		t.Fatalf("SSE usage = %+v", u)
	}

	if _, ok := ExtractGenAIUsageSSE([]byte(`{"candidates":[{"content":{"parts":[{"text":"x"}]}}]}`)); ok {
		t.Fatal("SSE chunk without usageMetadata must not report usage")
	}
}

// genaiStack wires the proxy against a fake NATIVE gemini upstream that
// records what it received and answers in genai shapes.
type genaiStack struct {
	upstream *httptest.Server
	proxy    *httptest.Server
	registry *Registry
	cfg      *Config

	gotAuthHeader string
	gotBearer     string
	gotQuery      string
	gotPath       string
	gotBody       string
}

func newGenAIStack(t *testing.T, costs map[string]Cost, streaming bool) *genaiStack {
	t.Helper()
	dir := t.TempDir()
	stack := &genaiStack{}

	keyFile := filepath.Join(dir, "crush.key")
	if err := os.WriteFile(keyFile, []byte("test-key-1"), 0o600); err != nil {
		t.Fatal(err)
	}

	stack.upstream = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		stack.gotPath = r.URL.Path
		stack.gotQuery = r.URL.RawQuery
		stack.gotAuthHeader = r.Header.Get("X-Goog-Api-Key")
		stack.gotBearer = r.Header.Get("Authorization")
		stack.gotBody = string(body)

		if streaming {
			w.Header().Set("Content-Type", "text/event-stream")
			flusher := w.(http.Flusher)
			for _, chunk := range []string{
				`data: {"candidates":[{"content":{"parts":[{"text":"Hel"}]}}]}`,
				`data: {"candidates":[{"content":{"parts":[{"text":"lo"}]}}]}`,
				`data: {"candidates":[{"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":9,"candidatesTokenCount":2,"thoughtsTokenCount":3,"cachedContentTokenCount":4,"totalTokenCount":14}}`,
			} {
				_, _ = io.WriteString(w, chunk+"\n\n")
				flusher.Flush()
			}
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"candidates":[{"content":{"parts":[{"text":"ok"}]}}],"usageMetadata":{"promptTokenCount":9,"candidatesTokenCount":2,"thoughtsTokenCount":3,"cachedContentTokenCount":4,"totalTokenCount":14}}`)
	}))

	stack.cfg = &Config{
		Listen:            "127.0.0.1:0",
		MetricsListen:     "127.0.0.1:0",
		LedgerPath:        filepath.Join(dir, "usage.jsonl"),
		InjectStreamUsage: true,
		Clients:           []Client{{Name: "crush", KeyFile: keyFile, key: "test-key-1"}},
		Upstreams: []Upstream{
			{Name: "gemini", BaseURL: stack.upstream.URL, APIKey: "up-gemini-key", AuthStyle: "x-goog-api-key"},
		},
		Costs: costs,
	}

	stack.registry = NewRegistry()
	ledger, err := OpenLedger(stack.cfg.LedgerPath, slog.Default())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ledger.Close() })

	proxy := NewProxy(stack.cfg, stack.registry, ledger, slog.Default())
	stack.proxy = httptest.NewServer(proxy)
	t.Cleanup(stack.upstream.Close)
	t.Cleanup(stack.proxy.Close)
	return stack
}

// postGenAI sends a native-shape request authenticated via Google's
// header — exactly what crush's gemini provider does.
func (s *genaiStack) postGenAI(path, query, body string) *http.Response {
	req, _ := http.NewRequest(http.MethodPost, s.proxy.URL+path+"?"+query, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Goog-Api-Key", "test-key-1")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		panic(err)
	}
	return resp
}

func TestProxyGenAIStreamingEndToEnd(t *testing.T) {
	s := newGenAIStack(t, map[string]Cost{"gemini-2.5-flash": {Input: 2, Output: 4, CachedInput: 0.5}}, true)

	genaiBody := `{"contents":[{"role":"user","parts":[{"text":"hi"}]}],"generationConfig":{"maxOutputTokens":16}}`
	resp := s.postGenAI("/v1/gemini/v1beta/models/gemini-2.5-flash:streamGenerateContent", "alt=sse", genaiBody)
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	raw, _ := io.ReadAll(resp.Body)
	if !strings.Contains(string(raw), `"text":"Hel"`) || !strings.Contains(string(raw), "usageMetadata") {
		t.Fatalf("stream not passed through verbatim:\n%s", raw)
	}

	if s.gotPath != "/v1beta/models/gemini-2.5-flash:streamGenerateContent" {
		t.Fatalf("upstream path = %q", s.gotPath)
	}
	if s.gotQuery != "alt=sse" {
		t.Fatalf("query string dropped: got %q, want alt=sse", s.gotQuery)
	}
	if s.gotAuthHeader != "up-gemini-key" {
		t.Fatalf("upstream X-Goog-Api-Key = %q, want the upstream key", s.gotAuthHeader)
	}
	if s.gotBearer != "" {
		t.Fatalf("Authorization must not be sent to a native upstream, got %q", s.gotBearer)
	}
	if s.gotBody != genaiBody {
		t.Fatalf("genai body must pass through UNTOUCHED (no include_usage injection):\nsent:  %s\ngot:   %s", genaiBody, s.gotBody)
	}

	out := s.registry.Render()
	// cost: (9-4)*2/1e6 + 4*0.5/1e6 + (2+3)*4/1e6 = 0.000032
	for _, want := range []string{
		`ai_meter_requests_total{client="crush",upstream="gemini",model="gemini-2.5-flash",code="200"} 1`,
		`ai_meter_tokens_total{client="crush",upstream="gemini",model="gemini-2.5-flash",kind="prompt"} 9`,
		`ai_meter_tokens_total{client="crush",upstream="gemini",model="gemini-2.5-flash",kind="completion"} 5`,
		`ai_meter_tokens_total{client="crush",upstream="gemini",model="gemini-2.5-flash",kind="cached"} 4`,
		`ai_meter_cost_usd_total{client="crush",upstream="gemini",model="gemini-2.5-flash"} 3.2e-05`,
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("metrics missing %q\nexposition:\n%s", want, out)
		}
	}
}

func TestProxyGenAIBuffered(t *testing.T) {
	s := newGenAIStack(t, nil, false)

	resp := s.postGenAI("/v1/gemini/v1beta/models/gemini-2.5-pro:generateContent", "", `{"contents":[{"role":"user","parts":[{"text":"hi"}]}]}`)
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if _, ok := body["candidates"]; !ok {
		t.Fatalf("upstream body not forwarded verbatim: %v", body)
	}

	out := s.registry.Render()
	for _, want := range []string{
		`ai_meter_requests_total{client="crush",upstream="gemini",model="gemini-2.5-pro",code="200"} 1`,
		`ai_meter_tokens_total{client="crush",upstream="gemini",model="gemini-2.5-pro",kind="prompt"} 9`,
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("metrics missing %q\nexposition:\n%s", want, out)
		}
	}
}

func TestProxyGenAIRejectsWrongKey(t *testing.T) {
	s := newGenAIStack(t, nil, true)

	req, _ := http.NewRequest(http.MethodPost, s.proxy.URL+"/v1/gemini/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse", strings.NewReader(`{}`))
	req.Header.Set("X-Goog-Api-Key", "wrong-key")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("want 401 for wrong X-Goog-Api-Key, got %d", resp.StatusCode)
	}
	if !strings.Contains(s.registry.Render(), "ai_meter_unauthorized_total 1") {
		t.Fatal("unauthorized metric not incremented")
	}
}
