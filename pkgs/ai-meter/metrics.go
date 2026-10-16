package main

import (
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

// Record is one completed AI call — the unit of both the metrics registry
// and the JSONL ledger.
type Record struct {
	Client           string
	Upstream         string
	Model            string
	Status           int
	Stream           bool
	Path             string
	PromptTokens     int
	CompletionTokens int
	CachedTokens     int
	CostUSD          float64
	DurationMS       int64
	// TTFTMS: >= 0 is a valid time-to-first-byte sample in milliseconds
	// (0 is legal — sub-millisecond streams truncate to it). <0 means no
	// sample: non-streaming call, or the stream ended before any byte.
	TTFTMS       int64
	UsageMissing bool // upstream returned no usage block
}

// Registry is a minimal hand-rolled Prometheus registry. Counters and
// sum/count pairs suffice for the dashboards this exists to feed; label
// cardinality is bounded by config (client, upstream) and by the model
// names clients actually request.
type Registry struct {
	mu sync.Mutex

	requests     map[reqKey]float64
	tokens       map[tokenKey]float64
	cost         map[costKey]float64
	secondsSum   map[durKey]float64
	secondsCount map[durKey]float64
	ttftSum      map[durKey]float64
	ttftCount    map[durKey]float64

	active         float64
	unauthorized   float64
	meteringErrors float64
	startTime      time.Time
}

type reqKey struct{ client, upstream, model, code string }
type tokenKey struct {
	client, upstream, model, kind string
}
type costKey struct{ client, upstream, model string }
type durKey struct {
	client, upstream, model string
	stream                  bool
}

func NewRegistry() *Registry {
	return &Registry{
		requests:      map[reqKey]float64{},
		tokens:        map[tokenKey]float64{},
		cost:          map[costKey]float64{},
		secondsSum:    map[durKey]float64{},
		secondsCount:  map[durKey]float64{},
		ttftSum:       map[durKey]float64{},
		ttftCount:     map[durKey]float64{},
		startTime:     time.Now(),
	}
}

// Begin marks a request as in flight.
func (r *Registry) Begin() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.active++
}

// End clears the in-flight mark.
func (r *Registry) End() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.active--
}

// Unauthorized counts rejected client authentications.
func (r *Registry) Unauthorized() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.unauthorized++
}

// MeteringError counts recording failures (ledger write errors, missing
// usage) — must stay visible instead of failing live traffic.
func (r *Registry) MeteringError() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.meteringErrors++
}

// Record folds one completed call into every metric family.
func (r *Registry) Record(rec Record) {
	r.mu.Lock()
	defer r.mu.Unlock()

	code := fmt.Sprintf("%d", rec.Status)
	r.requests[reqKey{rec.Client, rec.Upstream, rec.Model, code}]++
	r.tokens[tokenKey{rec.Client, rec.Upstream, rec.Model, "prompt"}] += float64(rec.PromptTokens)
	r.tokens[tokenKey{rec.Client, rec.Upstream, rec.Model, "completion"}] += float64(rec.CompletionTokens)
	r.tokens[tokenKey{rec.Client, rec.Upstream, rec.Model, "cached"}] += float64(rec.CachedTokens)
	r.cost[costKey{rec.Client, rec.Upstream, rec.Model}] += rec.CostUSD

	dk := durKey{rec.Client, rec.Upstream, rec.Model, rec.Stream}
	r.secondsSum[dk] += float64(rec.DurationMS) / 1000
	r.secondsCount[dk]++
	if rec.Stream && rec.TTFTMS >= 0 {
		r.ttftSum[dk] += float64(rec.TTFTMS) / 1000
		r.ttftCount[dk]++
	}
}

// Render produces the Prometheus text exposition format. Series are
// sorted within each family for stable output and test diffs.
func (r *Registry) Render() string {
	r.mu.Lock()
	defer r.mu.Unlock()

	var b strings.Builder

	reqs := make([]reqKey, 0, len(r.requests))
	for k := range r.requests {
		reqs = append(reqs, k)
	}
	sort.Slice(reqs, func(i, j int) bool {
		a, c := reqs[i], reqs[j]
		return a.client < c.client || a.client == c.client && (a.upstream < c.upstream || a.upstream == c.upstream && (a.model < c.model || a.model == c.model && a.code < c.code))
	})
	b.WriteString("# HELP ai_meter_requests_total Completed AI calls by client, upstream, model and HTTP status.\n")
	b.WriteString("# TYPE ai_meter_requests_total counter\n")
	for _, k := range reqs {
		writeSeries(&b, "ai_meter_requests_total", r.requests[k], "client", k.client, "upstream", k.upstream, "model", k.model, "code", k.code)
	}

	toks := make([]tokenKey, 0, len(r.tokens))
	for k := range r.tokens {
		toks = append(toks, k)
	}
	sort.Slice(toks, func(i, j int) bool {
		a, c := toks[i], toks[j]
		return a.client < c.client || a.client == c.client && (a.upstream < c.upstream || a.upstream == c.upstream && (a.model < c.model || a.model == c.model && a.kind < c.kind))
	})
	b.WriteString("# HELP ai_meter_tokens_total Tokens by direction. 'cached' is a subset of 'prompt'.\n")
	b.WriteString("# TYPE ai_meter_tokens_total counter\n")
	for _, k := range toks {
		writeSeries(&b, "ai_meter_tokens_total", r.tokens[k], "client", k.client, "upstream", k.upstream, "model", k.model, "kind", k.kind)
	}

	costs := make([]costKey, 0, len(r.cost))
	for k := range r.cost {
		costs = append(costs, k)
	}
	sort.Slice(costs, func(i, j int) bool {
		a, c := costs[i], costs[j]
		return a.client < c.client || a.client == c.client && (a.upstream < c.upstream || a.upstream == c.upstream && a.model < c.model)
	})
	b.WriteString("# HELP ai_meter_cost_usd_total Estimated spend in USD from the configured per-model cost table (0 for unknown and local models).\n")
	b.WriteString("# TYPE ai_meter_cost_usd_total counter\n")
	for _, k := range costs {
		writeSeries(&b, "ai_meter_cost_usd_total", r.cost[k], "client", k.client, "upstream", k.upstream, "model", k.model)
	}

	durs := make([]durKey, 0, len(r.secondsCount))
	for k := range r.secondsCount {
		durs = append(durs, k)
	}
	sort.Slice(durs, func(i, j int) bool {
		a, c := durs[i], durs[j]
		return a.client < c.client || a.client == c.client && (a.upstream < c.upstream || a.upstream == c.upstream && (a.model < c.model || a.model == c.model && !a.stream && c.stream))
	})
	b.WriteString("# HELP ai_meter_request_seconds_sum Total request wall time in seconds.\n")
	b.WriteString("# TYPE ai_meter_request_seconds_sum counter\n")
	for _, k := range durs {
		writeSeries(&b, "ai_meter_request_seconds_sum", r.secondsSum[k], "client", k.client, "upstream", k.upstream, "model", k.model, "stream", fmt.Sprintf("%t", k.stream))
	}
	b.WriteString("# HELP ai_meter_request_seconds_count Completed requests.\n")
	b.WriteString("# TYPE ai_meter_request_seconds_count counter\n")
	for _, k := range durs {
		writeSeries(&b, "ai_meter_request_seconds_count", r.secondsCount[k], "client", k.client, "upstream", k.upstream, "model", k.model, "stream", fmt.Sprintf("%t", k.stream))
	}

	ttfts := make([]durKey, 0, len(r.ttftCount))
	for k := range r.ttftCount {
		ttfts = append(ttfts, k)
	}
	sort.Slice(ttfts, func(i, j int) bool {
		a, c := ttfts[i], ttfts[j]
		return a.client < c.client || a.client == c.client && (a.upstream < c.upstream || a.upstream == c.upstream && a.model < c.model)
	})
	b.WriteString("# HELP ai_meter_ttft_seconds_sum Time to first streamed byte in seconds (streaming calls only).\n")
	b.WriteString("# TYPE ai_meter_ttft_seconds_sum counter\n")
	for _, k := range ttfts {
		writeSeries(&b, "ai_meter_ttft_seconds_sum", r.ttftSum[k], "client", k.client, "upstream", k.upstream, "model", k.model)
	}
	b.WriteString("# HELP ai_meter_ttft_seconds_count Streaming calls with a TTFT sample.\n")
	b.WriteString("# TYPE ai_meter_ttft_seconds_count counter\n")
	for _, k := range ttfts {
		writeSeries(&b, "ai_meter_ttft_seconds_count", r.ttftCount[k], "client", k.client, "upstream", k.upstream, "model", k.model)
	}

	b.WriteString("# HELP ai_meter_active_requests Requests currently in flight.\n")
	b.WriteString("# TYPE ai_meter_active_requests gauge\n")
	writeSeries(&b, "ai_meter_active_requests", r.active)

	b.WriteString("# HELP ai_meter_unauthorized_total Rejected client authentications.\n")
	b.WriteString("# TYPE ai_meter_unauthorized_total counter\n")
	writeSeries(&b, "ai_meter_unauthorized_total", r.unauthorized)

	b.WriteString("# HELP ai_meter_metering_errors_total Metering failures (ledger or usage parse) that did NOT fail the live call.\n")
	b.WriteString("# TYPE ai_meter_metering_errors_total counter\n")
	writeSeries(&b, "ai_meter_metering_errors_total", r.meteringErrors)

	b.WriteString("# HELP ai_meter_start_time_seconds Process start time (Unix).\n")
	b.WriteString("# TYPE ai_meter_start_time_seconds gauge\n")
	writeSeries(&b, "ai_meter_start_time_seconds", float64(r.startTime.Unix()))

	return b.String()
}

func writeSeries(b *strings.Builder, name string, value float64, labelPairs ...string) {
	b.WriteString(name)
	if len(labelPairs) > 0 {
		b.WriteString("{")
		for i := 0; i < len(labelPairs); i += 2 {
			if i > 0 {
				b.WriteString(",")
			}
			fmt.Fprintf(b, "%s=\"%s\"", labelPairs[i], escapeLabel(labelPairs[i+1]))
		}
		b.WriteString("}")
	}
	fmt.Fprintf(b, " %v\n", value)
}

func escapeLabel(v string) string {
	r := strings.NewReplacer(`\`, `\\`, "\n", `\n`, `"`, `\"`)
	return r.Replace(v)
}
