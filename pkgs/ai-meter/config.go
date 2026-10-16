package main

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"strings"
)

// Client is one consuming app. The proxy key identifies it for
// attribution; keys are loaded at startup from key files rendered by the
// host (runtime-minted, never committed).
type Client struct {
	Name    string `json:"name"`
	KeyFile string `json:"key_file"`

	key string
}

// Upstream is one OpenAI-compatible backend. Local backends
// (llama.cpp, FastFlowLM) use the literal key "unused" — the header is
// still sent, matching those servers' key-ignoring behavior.
// AuthStyle selects how the upstream key is presented: "bearer"
// (default, OpenAI-compatible) or "x-goog-api-key" (native Google
// GenAI endpoints reject Bearer API keys).
type Upstream struct {
	Name      string `json:"name"`
	BaseURL   string `json:"base_url"`
	APIKey    string `json:"api_key"`
	AuthStyle string `json:"auth_style,omitempty"`
}

// Cost is USD per 1M tokens, matching provider pricing pages and crush's
// own --price-input/--price-output convention.
type Cost struct {
	Input       float64 `json:"input"`
	Output      float64 `json:"output"`
	CachedInput float64 `json:"cached_input,omitempty"`
}

type Config struct {
	Listen       string               `json:"listen"`
	MetricsListen string              `json:"metrics_listen"`
	LedgerPath   string               `json:"ledger_path"`
	InjectStreamUsage bool            `json:"inject_stream_usage"`
	Clients      []Client             `json:"clients"`
	Upstreams    []Upstream           `json:"upstreams"`
	Costs        map[string]Cost      `json:"costs"`
}

func LoadConfig(path string) (*Config, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg Config
	// Default true: absent inject_stream_usage keeps injection on; an
	// explicit false disables it.
	cfg.InjectStreamUsage = true
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	if err := cfg.loadAndValidate(); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (c *Config) loadAndValidate() error {
	if c.Listen == "" || c.MetricsListen == "" {
		return fmt.Errorf("listen and metrics_listen are required")
	}
	if _, err := url.Parse("http://" + c.Listen); err != nil {
		return fmt.Errorf("listen address: %w", err)
	}
	if len(c.Clients) == 0 {
		return fmt.Errorf("at least one client is required")
	}
	if len(c.Upstreams) == 0 {
		return fmt.Errorf("at least one upstream is required")
	}

	seenClients := map[string]bool{}
	seenKeys := map[string]string{}
	for i := range c.Clients {
		cl := &c.Clients[i]
		if cl.Name == "" || cl.KeyFile == "" {
			return fmt.Errorf("client %d: name and key_file are required", i)
		}
		if seenClients[cl.Name] {
			return fmt.Errorf("duplicate client name %q", cl.Name)
		}
		seenClients[cl.Name] = true

		raw, err := os.ReadFile(cl.KeyFile)
		if err != nil {
			return fmt.Errorf("client %s: read key file: %w", cl.Name, err)
		}
		key := strings.TrimSpace(string(raw))
		if key == "" {
			return fmt.Errorf("client %s: key file %s is empty", cl.Name, cl.KeyFile)
		}
		if other, dup := seenKeys[key]; dup {
			return fmt.Errorf("clients %s and %s share a key", other, cl.Name)
		}
		seenKeys[key] = cl.Name
		cl.key = key
	}

	seenUpstreams := map[string]bool{}
	for i := range c.Upstreams {
		up := &c.Upstreams[i]
		if up.Name == "" || up.BaseURL == "" {
			return fmt.Errorf("upstream %d: name and base_url are required", i)
		}
		if seenUpstreams[up.Name] {
			return fmt.Errorf("duplicate upstream name %q", up.Name)
		}
		seenUpstreams[up.Name] = true
		up.BaseURL = strings.TrimSuffix(up.BaseURL, "/")
		if up.APIKey == "" {
			up.APIKey = "unused"
		}
		switch up.AuthStyle {
		case "":
			up.AuthStyle = "bearer"
		case "bearer", "x-goog-api-key":
		default:
			return fmt.Errorf("upstream %s: unknown auth_style %q (want bearer or x-goog-api-key)", up.Name, up.AuthStyle)
		}
	}
	return nil
}

// UpstreamNames returns the configured upstream names in config order.
func (c *Config) UpstreamNames() []string {
	names := make([]string, len(c.Upstreams))
	for i, up := range c.Upstreams {
		names[i] = up.Name
	}
	return names
}

// CostFor returns the cost table entry for a model, with the upstream
// prefix stripped ("zai/glm-5.3-flash" → "glm-5.3-flash").
func (c *Config) CostFor(model string) Cost {
	if cost, ok := c.Costs[model]; ok {
		return cost
	}
	if _, stripped, found := strings.Cut(model, "/"); found {
		if cost, ok := c.Costs[stripped]; ok {
			return cost
		}
	}
	return Cost{}
}
