package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func writeTemp(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "file")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestParseRequest(t *testing.T) {
	tests := []struct {
		name        string
		body        string
		wantModel   string
		wantStream  bool
	}{
		{"plain", `{"model":"glm-5.3-flash","messages":[]}`, "glm-5.3-flash", false},
		{"streaming", `{"model":"kimi-k2","stream":true}`, "kimi-k2", true},
		{"unknown fields kept", `{"model":"m","weird_field":{"nested":[1,2]}}`, "m", false},
		{"no model", `{"messages":[]}`, "", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, _, err := ParseRequest([]byte(tt.body))
			if err != nil {
				t.Fatalf("ParseRequest: %v", err)
			}
			if info.Model != tt.wantModel || info.Stream != tt.wantStream {
				t.Fatalf("got %+v, want model=%q stream=%v", info, tt.wantModel, tt.wantStream)
			}
		})
	}

	if _, _, err := ParseRequest([]byte("not json")); err == nil {
		t.Fatal("expected error for non-JSON body")
	}
}

func TestInjectStreamUsage(t *testing.T) {
	enabled := true
	disabled := false

	tests := []struct {
		name     string
		body     string
		info     RequestInfo
		setting  *bool
		wantSame bool
		wantSet  bool
	}{
		{
			name:     "adds include_usage to streaming request",
			body:     `{"model":"m","stream":true}`,
			info:     RequestInfo{Model: "m", Stream: true},
			setting:  &enabled,
			wantSame: false,
			wantSet:  true,
		},
		{
			name:     "leaves existing include_usage",
			body:     `{"model":"m","stream":true,"stream_options":{"include_usage":true}}`,
			info:     RequestInfo{Model: "m", Stream: true},
			setting:  &enabled,
			wantSame: true,
		},
		{
			name:     "leaves non-streaming alone",
			body:     `{"model":"m"}`,
			info:     RequestInfo{Model: "m"},
			setting:  &enabled,
			wantSame: true,
		},
		{
			name:     "disabled leaves streaming alone",
			body:     `{"model":"m","stream":true}`,
			info:     RequestInfo{Model: "m", Stream: true},
			setting:  &disabled,
			wantSame: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			setting := true
			if tt.setting != nil {
				setting = *tt.setting
			}
			out := InjectStreamUsage([]byte(tt.body), tt.info, setting)
			if tt.wantSame && string(out) != tt.body {
				t.Fatalf("body changed: %s", out)
			}
			if tt.wantSet {
				var payload map[string]any
				if err := json.Unmarshal(out, &payload); err != nil {
					t.Fatalf("injected body not JSON: %v", err)
				}
				opts, ok := payload["stream_options"].(map[string]any)
				if !ok || opts["include_usage"] != true {
					t.Fatalf("stream_options.include_usage not set: %s", out)
				}
			}
		})
	}
}

func TestExtractUsageJSON(t *testing.T) {
	body := `{"id":"x","choices":[],"usage":{"prompt_tokens":100,"completion_tokens":40,"total_tokens":140,"prompt_tokens_details":{"cached_tokens":60}}}`
	usage, ok := ExtractUsageJSON([]byte(body))
	if !ok {
		t.Fatal("expected usage")
	}
	if usage.PromptTokens != 100 || usage.CompletionTokens != 40 || usage.TotalTokens != 140 || usage.CachedTokens != 60 {
		t.Fatalf("got %+v", usage)
	}

	if _, ok := ExtractUsageJSON([]byte(`{"choices":[]}`)); ok {
		t.Fatal("usage absent should not be ok")
	}
	if _, ok := ExtractUsageJSON([]byte(`<html>nope</html>`)); ok {
		t.Fatal("non-JSON should not be ok")
	}

	// total_tokens filled in when the upstream omits it.
	usage, ok = ExtractUsageJSON([]byte(`{"usage":{"prompt_tokens":10,"completion_tokens":5}}`))
	if !ok || usage.TotalTokens != 15 {
		t.Fatalf("got %+v ok=%v", usage, ok)
	}
}

func TestExtractUsageSSE(t *testing.T) {
	chunk := `{"id":"c","choices":[{"delta":{"content":"hi"}}]}`
	if _, ok := ExtractUsageSSE([]byte(chunk)); ok {
		t.Fatal("content chunk has no usage")
	}
	final := `{"id":"c","choices":[],"usage":{"prompt_tokens":7,"completion_tokens":3,"total_tokens":10}}`
	usage, ok := ExtractUsageSSE([]byte(final))
	if !ok || usage.PromptTokens != 7 || usage.CompletionTokens != 3 {
		t.Fatalf("got %+v ok=%v", usage, ok)
	}
}

func TestLoadConfig(t *testing.T) {
	dir := t.TempDir()
	keyA := filepath.Join(dir, "a.key")
	keyB := filepath.Join(dir, "b.key")
	for path, content := range map[string]string{keyA: "key-a\n", keyB: "key-b"} {
		if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
	}

	writeCfg := func(body string) string {
		t.Helper()
		path := filepath.Join(dir, "config.json")
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		return path
	}

	baseCfg := func() string {
		return `{
			"listen":"127.0.0.1:0",
			"metrics_listen":"127.0.0.1:0",
			"ledger_path":"` + filepath.Join(dir, "usage.jsonl") + `",
			"clients":[{"name":"a","key_file":"` + keyA + `"},{"name":"b","key_file":"` + keyB + `"}],
			"upstreams":[{"name":"zai","base_url":"https://example.test/api/v4/","api_key":"k"}],
			"costs":{"glm-5.3-flash":{"input":0.15,"output":0.5,"cached_input":0.03}}
		}`
	}

	t.Run("valid", func(t *testing.T) {
		cfg, err := LoadConfig(writeCfg(baseCfg()))
		if err != nil {
			t.Fatalf("LoadConfig: %v", err)
		}
		if !cfg.InjectStreamUsage {
			t.Fatal("inject_stream_usage should default to true")
		}
		if cfg.Upstreams[0].BaseURL != "https://example.test/api/v4" {
			t.Fatalf("trailing slash not trimmed: %q", cfg.Upstreams[0].BaseURL)
		}
	})

	t.Run("explicit false honored", func(t *testing.T) {
		body := baseCfg()
		body = body[:len(body)-1] + `,"inject_stream_usage":false}`
		cfg, err := LoadConfig(writeCfg(body))
		if err != nil {
			t.Fatalf("LoadConfig: %v", err)
		}
		if cfg.InjectStreamUsage {
			t.Fatal("explicit false was overridden")
		}
	})

	t.Run("missing key file fails", func(t *testing.T) {
		body := `{"listen":"127.0.0.1:0","metrics_listen":"127.0.0.1:0","ledger_path":"x","clients":[{"name":"a","key_file":"/nonexistent"}],"upstreams":[{"name":"u","base_url":"https://x"}]}`
		if _, err := LoadConfig(writeCfg(body)); err == nil {
			t.Fatal("expected error for missing key file")
		}
	})

	t.Run("duplicate client keys fail", func(t *testing.T) {
		body := `{"listen":"127.0.0.1:0","metrics_listen":"127.0.0.1:0","ledger_path":"x","clients":[{"name":"a","key_file":"` + keyA + `"},{"name":"b","key_file":"` + keyA + `"}],"upstreams":[{"name":"u","base_url":"https://x"}]}`
		if _, err := LoadConfig(writeCfg(body)); err == nil {
			t.Fatal("expected error for duplicate keys")
		}
	})
}

func TestCostFor(t *testing.T) {
	cfg := &Config{Costs: map[string]Cost{
		"glm-5.3-flash": {Input: 0.15, Output: 0.5, CachedInput: 0.03},
	}}
	if got := cfg.CostFor("glm-5.3-flash"); got.Input != 0.15 {
		t.Fatalf("exact match failed: %+v", got)
	}
	if got := cfg.CostFor("zai/glm-5.3-flash"); got.Input != 0.15 {
		t.Fatalf("prefix-stripped match failed: %+v", got)
	}
	if got := cfg.CostFor("unknown"); got != (Cost{}) {
		t.Fatalf("unknown model should be zero cost: %+v", got)
	}
}
