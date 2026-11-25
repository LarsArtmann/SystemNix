package main

import (
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

// modelNone is the model label of a call that names no model: a passthrough
// route (model listing, uploads), a body that is not JSON, or the window
// before the request body has been read.
const modelNone = "none"

// modelName maps an absent model to modelNone so "no model" has exactly one
// label value across every metric family and the ledger.
func modelName(model string) string {
	if model == "" {
		return modelNone
	}
	return model
}

// Record is one completed AI call — the unit of the metrics registry, the
// JSONL ledger and the exported span.
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

	// Attempts is how many answers the upstream has given this call: 1
	// unless the proxy retried rate-limit rejections on its behalf, and 0
	// for a call it never sent (see Admission).
	Attempts int
	// QueueMS is how long the call waited in the proxy for the upstream to
	// have room, in milliseconds.
	QueueMS int64
	// UpstreamCode is the business code the upstream's error answer carried
	// ("1302" for a z.ai rate limit), empty when it named none.
	UpstreamCode string
	// Admission is how the call left a gated upstream (outcomeAdmitted and
	// the rest); empty for a call to an upstream without a gate.
	Admission string

	// StartedAt is when the proxy accepted the request, EndedAt when the call
	// was recorded. A duration alone cannot place a call on a timeline, so the
	// span needs both.
	StartedAt time.Time
	EndedAt   time.Time
	// Trace carries what only the span needs.
	Trace CallTrace
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
	inflight     map[inflightKey]float64

	admission       map[string]admissionGauge
	admissionWait   map[string]float64
	admissionWaited map[string]float64
	admissionKept   map[string]float64
	admissions      map[admissionKey]float64
	rejections      map[rejectionKey]float64

	unauthorized   float64
	meteringErrors float64
	spanExports    map[string]float64
	// costWithheld: a ledger replay is in progress and the cost counter is
	// not whole yet, so Render leaves the cost family out.
	costWithheld bool
	startTime    time.Time
}

type reqKey struct{ client, upstream, model, code string }
type tokenKey struct {
	client, upstream, model, kind string
}
type costKey struct{ client, upstream, model string }
type inflightKey struct{ client, upstream, model string }
type durKey struct {
	client, upstream, model string
	stream                  bool
}

// admissionGauge is the state of one gated upstream at a moment.
type admissionGauge struct {
	waiting        float64
	inflight       float64
	limit          float64
	quotaExhausted bool
}

type admissionKey struct{ client, upstream, model, outcome string }
type rejectionKey struct{ upstream, model, code, kind string }

func NewRegistry() *Registry {
	return &Registry{
		requests:        map[reqKey]float64{},
		tokens:          map[tokenKey]float64{},
		cost:            map[costKey]float64{},
		secondsSum:      map[durKey]float64{},
		secondsCount:    map[durKey]float64{},
		ttftSum:         map[durKey]float64{},
		ttftCount:       map[durKey]float64{},
		inflight:        map[inflightKey]float64{},
		admission:       map[string]admissionGauge{},
		admissionWait:   map[string]float64{},
		admissionWaited: map[string]float64{},
		admissionKept:   map[string]float64{},
		admissions:      map[admissionKey]float64{},
		rejections:      map[rejectionKey]float64{},
		spanExports:     map[string]float64{},
		startTime:       time.Now(),
	}
}

// Call is one request's in-flight mark. BeginCall issues it, SetModel moves
// it once the request names its model, and End clears it. A Call belongs to
// the single goroutine serving that request and is never reused after End.
type Call struct {
	registry *Registry
	key      inflightKey
}

// BeginCall marks a request as in flight under its client and upstream. The
// model is modelNone until SetModel names it. Keys are never removed, so an
// idle series keeps exposing 0 instead of disappearing between scrapes.
func (r *Registry) BeginCall(client, upstream string) *Call {
	r.mu.Lock()
	defer r.mu.Unlock()
	call := &Call{registry: r, key: inflightKey{client: client, upstream: upstream, model: modelNone}}
	r.inflight[call.key]++
	return call
}

// SetModel moves the in-flight mark to the series of the request's model.
func (c *Call) SetModel(model string) {
	if c.registry == nil {
		return
	}
	r := c.registry
	r.mu.Lock()
	defer r.mu.Unlock()
	next := inflightKey{client: c.key.client, upstream: c.key.upstream, model: modelName(model)}
	if next == c.key {
		return
	}
	r.inflight[c.key]--
	r.inflight[next]++
	c.key = next
}

// End clears the in-flight mark. Calling it again, or after SetModel, is a
// no-op, so the gauge can never be decremented below its true value.
func (c *Call) End() {
	if c.registry == nil {
		return
	}
	r := c.registry
	r.mu.Lock()
	defer r.mu.Unlock()
	r.inflight[c.key]--
	c.registry = nil
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

// RestoreCost folds a replayed call into the cost counter alone. It runs
// once per ledger entry while the proxy is already serving, so a call that
// arrives meanwhile is simply added on top.
func (r *Registry) RestoreCost(rec Record) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.cost[costKey{rec.Client, rec.Upstream, rec.Model}] += rec.CostUSD
}

// BeginCostReplay withholds the cost family from Render until
// EndCostReplay, so a half-replayed total is never scraped as if it were
// the whole spend.
func (r *Registry) BeginCostReplay() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.costWithheld = true
}

// EndCostReplay publishes the cost counter again, however the replay went.
func (r *Registry) EndCostReplay() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.costWithheld = false
}

// SpanExported counts count spans by how handing them to the OTLP endpoint
// went (spanOutcomeOK, spanOutcomeFailed, spanOutcomeDropped).
func (r *Registry) SpanExported(outcome string, count float64) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.spanExports[outcome] += count
}

// AdmissionState replaces what is true of one gated upstream right now: how
// many calls wait there, how many are in flight, the current allowance, and
// whether its usage quota is known to be spent.
func (r *Registry) AdmissionState(upstream string, waiting, inflight, limit int, quotaExhausted bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.admission[upstream] = admissionGauge{
		waiting:        float64(waiting),
		inflight:       float64(inflight),
		limit:          float64(limit),
		quotaExhausted: quotaExhausted,
	}
}

// AdmissionWaited adds the time a call waited for the upstream to have
// room. The count of calls that waited grows only on a call's first wait
// (first), however many times it waits again.
func (r *Registry) AdmissionWaited(upstream string, waited time.Duration, first bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.admissionWait[upstream] += waited.Seconds()
	if first {
		r.admissionWaited[upstream]++
	}
}

// AdmissionKeptArrival counts a call that took the place of an earlier
// arrival: the client sent it again after the proxy sent it back.
func (r *Registry) AdmissionKeptArrival(upstream string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.admissionKept[upstream]++
}

// UpstreamRejection counts a 429 the upstream answered, by the business
// code in its body and by what that code means for the next request.
func (r *Registry) UpstreamRejection(upstream, model, code string, kind rejectionKind) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.rejections[rejectionKey{upstream, model, code, string(kind)}]++
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
	if rec.Admission != "" {
		r.admissions[admissionKey{rec.Client, rec.Upstream, rec.Model, rec.Admission}]++
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
	if !r.costWithheld {
		b.WriteString("# HELP ai_meter_cost_usd_total Estimated spend in USD since the ledger began, priced at the CURRENT per-model cost table (replayed at every start, so a price row that lands late restates earlier usage; 0 for unknown and local models).\n")
		b.WriteString("# TYPE ai_meter_cost_usd_total counter\n")
		for _, k := range costs {
			writeSeries(&b, "ai_meter_cost_usd_total", r.cost[k], "client", k.client, "upstream", k.upstream, "model", k.model)
		}
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

	flights := make([]inflightKey, 0, len(r.inflight))
	for k := range r.inflight {
		flights = append(flights, k)
	}
	sort.Slice(flights, func(i, j int) bool {
		a, c := flights[i], flights[j]
		return a.client < c.client || a.client == c.client && (a.upstream < c.upstream || a.upstream == c.upstream && a.model < c.model)
	})
	b.WriteString("# HELP ai_meter_active_requests Requests currently in flight by client, upstream and model ('none' until the request body names one, and for routes that carry none).\n")
	b.WriteString("# TYPE ai_meter_active_requests gauge\n")
	for _, k := range flights {
		writeSeries(&b, "ai_meter_active_requests", r.inflight[k], "client", k.client, "upstream", k.upstream, "model", k.model)
	}

	// Admission control. Upstreams without a gate have no series here.
	gated := make([]string, 0, len(r.admission))
	for upstream := range r.admission {
		gated = append(gated, upstream)
	}
	sort.Strings(gated)
	writeGauge(&b, "ai_meter_admission_inflight", "Calls the proxy keeps in flight at the upstream.", gated, func(upstream string) float64 {
		return r.admission[upstream].inflight
	})
	writeGauge(&b, "ai_meter_admission_waiting", "Calls waiting for the upstream to have room.", gated, func(upstream string) float64 {
		return r.admission[upstream].waiting
	})
	writeGauge(&b, "ai_meter_admission_limit", "Calls the proxy currently allows in flight at the upstream: it starts at the configured ceiling, drops by one per rate-limit rejection, and grows back by one after a quiet interval.", gated, func(upstream string) float64 {
		return r.admission[upstream].limit
	})
	writeGauge(&b, "ai_meter_quota_exhausted", "1 while the upstream's usage quota is spent until the reset time it named.", gated, func(upstream string) float64 {
		if r.admission[upstream].quotaExhausted {
			return 1
		}
		return 0
	})

	waits := make([]string, 0, len(r.admissionWaited))
	for upstream := range r.admissionWaited {
		waits = append(waits, upstream)
	}
	sort.Strings(waits)
	b.WriteString("# HELP ai_meter_admission_wait_seconds_sum Time calls spent waiting for the upstream to have room, in seconds.\n")
	b.WriteString("# TYPE ai_meter_admission_wait_seconds_sum counter\n")
	for _, upstream := range waits {
		writeSeries(&b, "ai_meter_admission_wait_seconds_sum", r.admissionWait[upstream], "upstream", upstream)
	}
	b.WriteString("# HELP ai_meter_admission_wait_seconds_count Calls that waited for admission at least once.\n")
	b.WriteString("# TYPE ai_meter_admission_wait_seconds_count counter\n")
	for _, upstream := range waits {
		writeSeries(&b, "ai_meter_admission_wait_seconds_count", r.admissionWaited[upstream], "upstream", upstream)
	}
	kept := make([]string, 0, len(r.admissionKept))
	for upstream := range r.admissionKept {
		kept = append(kept, upstream)
	}
	sort.Strings(kept)
	b.WriteString("# HELP ai_meter_admission_kept_arrival_total Calls that took the place of an earlier arrival, because the client sent them again after the proxy sent them back.\n")
	b.WriteString("# TYPE ai_meter_admission_kept_arrival_total counter\n")
	for _, upstream := range kept {
		writeSeries(&b, "ai_meter_admission_kept_arrival_total", r.admissionKept[upstream], "upstream", upstream)
	}

	rejects := make([]rejectionKey, 0, len(r.rejections))
	for k := range r.rejections {
		rejects = append(rejects, k)
	}
	sort.Slice(rejects, func(i, j int) bool {
		a, c := rejects[i], rejects[j]
		return a.upstream < c.upstream || a.upstream == c.upstream && (a.model < c.model || a.model == c.model && (a.code < c.code || a.code == c.code && a.kind < c.kind))
	})
	b.WriteString("# HELP ai_meter_upstream_rejections_total HTTP 429 answers from a gated upstream by the business code in the body: kind=\"rate_limit\" (too much at once; counted against the allowance and, within the retry budget, retried) or kind=\"quota\" (a usage window is spent; passed through and not sent again before its reset).\n")
	b.WriteString("# TYPE ai_meter_upstream_rejections_total counter\n")
	for _, k := range rejects {
		writeSeries(&b, "ai_meter_upstream_rejections_total", r.rejections[k], "upstream", k.upstream, "model", k.model, "code", k.code, "kind", k.kind)
	}

	leaves := make([]admissionKey, 0, len(r.admissions))
	for k := range r.admissions {
		leaves = append(leaves, k)
	}
	sort.Slice(leaves, func(i, j int) bool {
		a, c := leaves[i], leaves[j]
		return a.client < c.client || a.client == c.client && (a.upstream < c.upstream || a.upstream == c.upstream && (a.model < c.model || a.model == c.model && a.outcome < c.outcome))
	})
	b.WriteString("# HELP ai_meter_admission_outcomes_total How calls to a gated upstream left the proxy: \"admitted\" (sent once, answered), \"absorbed\" (a rate-limit rejection was retried and a later attempt was answered), \"gave_up\" (the retries were spent, or the upstream asked to wait longer than the proxy waits; the client got the upstream's answer), \"timeout\" (the wait budget ran out, in the queue or between attempts), \"circuit\" (not sent: the upstream's usage quota is spent), \"cancelled\" (the client went away while the proxy waited on its behalf).\n")
	b.WriteString("# TYPE ai_meter_admission_outcomes_total counter\n")
	for _, k := range leaves {
		writeSeries(&b, "ai_meter_admission_outcomes_total", r.admissions[k], "client", k.client, "upstream", k.upstream, "model", k.model, "outcome", k.outcome)
	}

	// Every outcome is exposed, also at zero, so a rate or alert over it
	// never meets an absent series.
	b.WriteString("# HELP ai_meter_spans_exported_total Proxied calls by how handing their span to the OTLP endpoint went: \"ok\" (the endpoint accepted the batch), \"failed\" (the endpoint rejected it or never answered), \"dropped\" (the export queue was full, or the proxy stopped before the span was sent).\n")
	b.WriteString("# TYPE ai_meter_spans_exported_total counter\n")
	outcomes := []string{spanOutcomeDropped, spanOutcomeFailed, spanOutcomeOK}
	sort.Strings(outcomes)
	for _, outcome := range outcomes {
		writeSeries(&b, "ai_meter_spans_exported_total", r.spanExports[outcome], "outcome", outcome)
	}

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

// writeGauge writes one single-label gauge family, a series per key.
func writeGauge(b *strings.Builder, name, help string, keys []string, value func(string) float64) {
	b.WriteString("# HELP " + name + " " + help + "\n")
	b.WriteString("# TYPE " + name + " gauge\n")
	for _, key := range keys {
		writeSeries(b, name, value(key), "upstream", key)
	}
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
