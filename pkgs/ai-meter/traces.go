package main

// OTLP/JSON span export, the bridge into SigNoz's native AI observability.
//
// SigNoz lists a trace in its AI explorer as soon as one span carries
// gen_ai.request.model, gen_ai.tool.name or gen_ai.agent.name, and its AI
// overview reads tokens, cost, time to first token and errors off the
// OpenTelemetry GenAI semantic-convention attributes. One span per proxied
// call carries them. A call that names no model (model listing, uploads,
// countTokens) is exported as a plain span and stays out of the AI views.
//
// The package stays stdlib-only (pkgs/ai-meter.nix: vendorHash = null
// forever), so the OpenTelemetry SDK is not imported. OTLP over HTTP with
// JSON encoding is a stable wire contract and the SigNoz collector accepts it
// unmodified (verified against the deployed collector on 2026-11-25).
//
// Prompts and completions are never exported: only metadata about a call
// (who called which model, tokens, cost, latency, outcome) leaves the proxy.
//
// Cost: the self-hosted collector pipeline has no signozllmpricing processor
// (SigNoz deploys that one over OpAMP to managed collectors only), so the
// span carries the proxy's own price under the keys that processor would have
// written. The proxy is the cost authority; nothing else prices these calls.

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Export sizing. One span per proxied call; parallel agent sessions burst, so
// the queue absorbs spikes and the worker posts whatever is queued in batches.
const (
	spanQueueCapacity = 4096
	spanBatchMax      = 128
	spanExportTimeout = 5 * time.Second
	spanFailureLogGap = time.Minute

	// The instrumentation scope names the emitter in every span.
	scopeName = "github.com/larsartmann/systemnix/ai-meter"
)

// Span identity, in OTLP's numeric encoding.
const (
	spanKindClient    = 3 // SPAN_KIND_CLIENT: the proxy's call to the provider
	spanStatusCodeErr = 2 // STATUS_CODE_ERROR
)

// OpenTelemetry GenAI semantic-convention attributes, the subset SigNoz's AI
// observability reads, plus the HTTP and error attributes of a client span.
const (
	attrOperation        = "gen_ai.operation.name"
	attrRequestModel     = "gen_ai.request.model"
	attrProvider         = "gen_ai.provider.name"
	attrResponseModel    = "gen_ai.response.model"
	attrFinishReasons    = "gen_ai.response.finish_reasons"
	attrInputTokens      = "gen_ai.usage.input_tokens"
	attrOutputTokens     = "gen_ai.usage.output_tokens"
	attrCacheReadTokens  = "gen_ai.usage.cache_read.input_tokens"
	attrTimeToFirstToken = "gen_ai.server.ttft"

	// SigNoz's reserved cost keys. They live under a prefix SigNoz reserves
	// for its pricing processor; a processor that is ever added strips and
	// recomputes them from its own rules.
	attrCostInput     = "signoz.gen_ai.usage.input_tokens.cost"
	attrCostOutput    = "signoz.gen_ai.usage.output_tokens.cost"
	attrCostCacheRead = "signoz.gen_ai.usage.cache_read.input_tokens.cost"
	attrCostTotal     = "signoz.gen_ai.usage.tokens.cost"

	attrRequestMethod      = "http.request.method"
	attrResponseStatusCode = "http.response.status_code"
	attrErrorType          = "error.type"

	attrClient            = "ai_meter.client"
	attrUpstream          = "ai_meter.upstream"
	attrRoute             = "ai_meter.route"
	attrStream            = "ai_meter.stream"
	attrUsageMissing      = "ai_meter.usage_missing"
	attrUpstreamRequestID = "ai_meter.upstream_request_id"
)

// finishReasonError is gen_ai.response.finish_reasons of a call that failed
// before the provider could stop generating for a reason of its own.
const finishReasonError = "error"

// errorTypeUnreachable is error.type of a call whose upstream never answered.
const errorTypeUnreachable = "ai_meter.upstream_unreachable"

// Span-export outcomes, the label values of ai_meter_spans_exported_total.
const (
	spanOutcomeOK      = "ok"
	spanOutcomeFailed  = "failed"
	spanOutcomeDropped = "dropped"
)

// spanSink receives each call exactly once, after it ended.
type spanSink interface {
	Emit(rec *Record)
}

// noSpans is the sink of a proxy without an OTLP endpoint.
type noSpans struct{}

func (noSpans) Emit(*Record) {}

// TraceContext is the trace a client propagated into its request (W3C
// traceparent). TraceID is empty when the request carried none, carried one
// that does not parse, or carried one its sampler did not mark: the call then
// starts a trace of its own instead of dangling under a parent nobody records.
type TraceContext struct {
	TraceID      string
	ParentSpanID string
}

// traceContext reads the traceparent header value.
func traceContext(traceparent string) TraceContext {
	parts := strings.Split(traceparent, "-")
	if len(parts) != 4 || parts[0] != "00" {
		return TraceContext{}
	}
	flags, err := strconv.ParseUint(parts[3], 16, 8)
	if err != nil || flags&1 == 0 {
		return TraceContext{}
	}
	if !isHexID(parts[1], 16) || !isHexID(parts[2], 8) {
		return TraceContext{}
	}
	return TraceContext{TraceID: parts[1], ParentSpanID: parts[2]}
}

// isHexID reports whether s is the lowercase hex of exactly size bytes and
// not all zero (the invalid id in the W3C format).
func isHexID(s string, size int) bool {
	if len(s) != 2*size || strings.ToLower(s) != s {
		return false
	}
	raw, err := hex.DecodeString(s)
	if err != nil {
		return false
	}
	for _, b := range raw {
		if b != 0 {
			return true
		}
	}
	return false
}

// CallTrace is what the span of a call needs beyond its metering facts.
type CallTrace struct {
	// Method is the client's HTTP method; Route is the upstream-relative
	// sub-path the call went to ("chat/completions").
	Method string
	Route  string
	// Operation is the span's gen_ai.operation.name, empty for a call that
	// names no model.
	Operation string
	// ResponseModel is the model the upstream's answer names as the one that
	// served the call, empty when the answer names none.
	ResponseModel string
	// FinishReason is why the upstream stopped generating, in its own
	// spelling, empty when it did not say.
	FinishReason string
	// UpstreamRequestID is the upstream's correlation id of the call, empty
	// when it sent none.
	UpstreamRequestID string
	// TransportError is the cause of a call whose upstream never answered.
	TransportError string
	// Parent is the trace context the client propagated.
	Parent TraceContext
}

// genAIOperation names the GenAI operation of a metered route, the span's
// gen_ai.operation.name. The Responses API is the successor of chat
// completions and is recorded as a chat; ai_meter.route keeps the two apart.
func genAIOperation(subPath string, nativeGenAI bool) string {
	if nativeGenAI {
		return "generate_content"
	}
	switch subPath {
	case "chat/completions", "responses":
		return "chat"
	case "completions":
		return "text_completion"
	case "embeddings":
		return "embeddings"
	}
	return ""
}

// upstreamRequestID returns the provider's correlation id of a response, from
// whichever header the provider family uses.
func upstreamRequestID(header http.Header) string {
	for _, name := range []string{"X-Request-Id", "Request-Id", "X-Goog-Request-Id"} {
		if id := header.Get(name); id != "" {
			return id
		}
	}
	return ""
}

// transportCause reduces a transport error to its cause. The raw error of a
// failed request quotes the full upstream URL; only the cause is kept, so no
// URL can ever reach a span.
func transportCause(err error) string {
	var urlErr *url.Error
	if errors.As(err, &urlErr) && urlErr.Err != nil {
		return urlErr.Err.Error()
	}
	return err.Error()
}

// finishReasonAliases maps provider spellings onto the OpenTelemetry GenAI
// finish reasons so one reason groups under one value.
var finishReasonAliases = map[string]string{
	"tool_calls":        "tool_call",
	"function_call":     "tool_call",
	"tool_use":          "tool_call",
	"end_turn":          "stop",
	"stop_sequence":     "stop",
	"completed":         "stop",
	"max_tokens":        "length",
	"max_output_tokens": "length",
	"cancelled":         "error",
	"failed":            "error",
}

func normalizeFinishReason(reason string) string {
	reason = strings.ToLower(strings.TrimSpace(reason))
	if alias, ok := finishReasonAliases[reason]; ok {
		return alias
	}
	return reason
}

// responseMeta is what the upstream's answer says about itself: which model
// actually served the call, and why generation stopped. Both protocols the
// proxy meters are read with one decode: OpenAI's `model` and
// `choices[].finish_reason` (plus the Responses API's `status`), and Google's
// `modelVersion` and `candidates[].finishReason`.
type responseMeta struct {
	Model        string
	FinishReason string
}

// observe reads one response body, buffered or a single SSE data payload. The
// first finish reason wins; a later payload cannot overwrite it.
func (m *responseMeta) observe(payload []byte) {
	var body struct {
		Model        string `json:"model"`
		ModelVersion string `json:"modelVersion"`
		Status       string `json:"status"`
		Incomplete   *struct {
			Reason string `json:"reason"`
		} `json:"incomplete_details"`
		Choices []struct {
			FinishReason *string `json:"finish_reason"`
		} `json:"choices"`
		Candidates []struct {
			FinishReason *string `json:"finishReason"`
		} `json:"candidates"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return
	}
	if body.Model != "" {
		m.Model = body.Model
	} else if body.ModelVersion != "" {
		m.Model = body.ModelVersion
	}
	if m.FinishReason != "" {
		return
	}
	for _, choice := range body.Choices {
		if choice.FinishReason != nil && *choice.FinishReason != "" {
			m.FinishReason = normalizeFinishReason(*choice.FinishReason)
			return
		}
	}
	for _, candidate := range body.Candidates {
		if candidate.FinishReason != nil && *candidate.FinishReason != "" {
			m.FinishReason = normalizeFinishReason(*candidate.FinishReason)
			return
		}
	}
	switch body.Status {
	case "":
	case "incomplete":
		if body.Incomplete != nil && body.Incomplete.Reason != "" {
			m.FinishReason = normalizeFinishReason(body.Incomplete.Reason)
		} else {
			m.FinishReason = "incomplete"
		}
	default:
		m.FinishReason = normalizeFinishReason(body.Status)
	}
}

// SpanExporter ships the span of every proxied call to an OTLP/HTTP endpoint.
//
// Emit never blocks the request path: a span is queued, a single worker posts
// the queue in batches, and a full queue drops the span and counts it. A
// failed post is counted and dropped the same way; losing telemetry is never
// allowed to cost memory or slow a call.
type SpanExporter struct {
	endpoint string
	priceFor func(model string) Cost
	registry *Registry
	logger   *slog.Logger
	client   *http.Client
	resource []otlpAttribute
	queue    chan *otlpSpan
	done     chan struct{}
	worker   sync.WaitGroup

	logMu          sync.Mutex
	lastFailureLog time.Time
}

// NewSpanExporter starts the worker of an exporter for cfg. cfg must name an
// OTLP endpoint; a proxy without one uses noSpans.
func NewSpanExporter(cfg *Config, registry *Registry, logger *slog.Logger) *SpanExporter {
	resource := []otlpAttribute{stringAttr("service.name", "ai-meter")}
	if cfg.DeploymentEnvironment != "" {
		resource = append(resource, stringAttr("deployment.environment", cfg.DeploymentEnvironment))
	}
	sort.Slice(resource, func(i, j int) bool { return resource[i].Key < resource[j].Key })
	e := &SpanExporter{
		endpoint: otlpTracesURL(cfg.OTLPEndpoint),
		registry: registry,
		logger:   logger,
		client: &http.Client{
			Timeout: spanExportTimeout,
			Transport: &http.Transport{
				MaxIdleConns:        4,
				MaxIdleConnsPerHost: 4,
				IdleConnTimeout:     90 * time.Second,
			},
		},
		resource: resource,
		queue:    make(chan *otlpSpan, spanQueueCapacity),
		done:     make(chan struct{}),
		priceFor: cfg.CostFor,
	}
	e.worker.Add(1)
	go e.run()
	return e
}

// Endpoint is the full URL spans are posted to.
func (e *SpanExporter) Endpoint() string { return e.endpoint }

// otlpTracesURL completes a configured endpoint: a base URL
// ("http://127.0.0.1:4318") gets the OTLP traces path appended, a full one is
// taken as is.
func otlpTracesURL(endpoint string) string {
	endpoint = strings.TrimSuffix(endpoint, "/")
	if u, err := url.Parse(endpoint); err == nil && u.Path == "" {
		return endpoint + "/v1/traces"
	}
	return endpoint
}

// Emit queues the span of one recorded call.
func (e *SpanExporter) Emit(rec *Record) {
	span, err := rec.span(e.priceFor(rec.Model))
	if err != nil {
		e.registry.SpanExported(spanOutcomeFailed, 1)
		e.logFailure(err)
		return
	}
	select {
	case e.queue <- span:
	default:
		e.registry.SpanExported(spanOutcomeDropped, 1)
	}
}

// Shutdown stops the worker once every queued span had its chance to be
// posted. Spans still queued when ctx ends are counted as dropped.
func (e *SpanExporter) Shutdown(ctx context.Context) {
	close(e.done)
	finished := make(chan struct{})
	go func() {
		e.worker.Wait()
		close(finished)
	}()
	select {
	case <-finished:
	case <-ctx.Done():
		e.registry.SpanExported(spanOutcomeDropped, float64(len(e.queue)))
	}
}

func (e *SpanExporter) run() {
	defer e.worker.Done()
	for {
		select {
		case <-e.done:
			for {
				select {
				case span := <-e.queue:
					e.send(e.collect(span))
				default:
					return
				}
			}
		case span := <-e.queue:
			e.send(e.collect(span))
		}
	}
}

// collect takes the spans queued behind first, up to one batch.
func (e *SpanExporter) collect(first *otlpSpan) []*otlpSpan {
	batch := make([]*otlpSpan, 0, spanBatchMax)
	batch = append(batch, first)
	for len(batch) < spanBatchMax {
		select {
		case span := <-e.queue:
			batch = append(batch, span)
		default:
			return batch
		}
	}
	return batch
}

func (e *SpanExporter) send(batch []*otlpSpan) {
	body, err := json.Marshal(otlpTraces{ResourceSpans: []otlpResourceSpans{{
		Resource: otlpResource{Attributes: e.resource},
		ScopeSpans: []otlpScopeSpans{{
			Scope: otlpScope{Name: scopeName},
			Spans: batch,
		}},
	}}})
	if err == nil {
		err = e.post(body)
	}
	if err != nil {
		e.registry.SpanExported(spanOutcomeFailed, float64(len(batch)))
		e.logFailure(err)
		return
	}
	e.registry.SpanExported(spanOutcomeOK, float64(len(batch)))
}

func (e *SpanExporter) post(body []byte) error {
	req, err := http.NewRequest(http.MethodPost, e.endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := e.client.Do(req)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return fmt.Errorf("OTLP endpoint answered %d: %s", resp.StatusCode, strings.TrimSpace(string(snippet)))
	}
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 64<<10))
	return nil
}

// logFailure reports an export failure at most once per spanFailureLogGap: a
// dead endpoint fails on every batch, and one line a minute is the whole
// diagnosis.
func (e *SpanExporter) logFailure(err error) {
	e.logMu.Lock()
	defer e.logMu.Unlock()
	if time.Since(e.lastFailureLog) < spanFailureLogGap && !e.lastFailureLog.IsZero() {
		return
	}
	e.lastFailureLog = time.Now()
	e.logger.Warn("span export failed - the call is metered, only its trace is lost", "err", err)
}

// span builds the OTLP span of a recorded call.
func (rec *Record) span(price Cost) (*otlpSpan, error) {
	if rec.StartedAt.IsZero() || rec.EndedAt.IsZero() {
		return nil, errors.New("record carries no start or end time")
	}
	ids := make([]byte, 24) // 16 bytes trace id, 8 bytes span id
	if _, err := rand.Read(ids); err != nil {
		return nil, fmt.Errorf("generate span ids: %w", err)
	}
	traceID, parentSpanID := hex.EncodeToString(ids[:16]), ""
	if rec.Trace.Parent.TraceID != "" {
		traceID, parentSpanID = rec.Trace.Parent.TraceID, rec.Trace.Parent.ParentSpanID
	}
	return &otlpSpan{
		TraceID:       traceID,
		SpanID:        hex.EncodeToString(ids[16:]),
		ParentSpanID:  parentSpanID,
		Name:          rec.spanName(),
		Kind:          spanKindClient,
		StartUnixNano: strconv.FormatInt(rec.StartedAt.UnixNano(), 10),
		EndUnixNano:   strconv.FormatInt(rec.EndedAt.UnixNano(), 10),
		Attributes:    rec.attributes(price),
		Status:        rec.spanStatus(),
	}, nil
}

// spanName follows the GenAI convention "{operation} {model}"; a call without
// a model is named after its HTTP method and route.
func (rec *Record) spanName() string {
	if rec.Trace.Operation != "" {
		return rec.Trace.Operation + " " + rec.Model
	}
	return strings.TrimSpace(rec.Trace.Method + " " + rec.Trace.Route)
}

// spanStatus marks a failed call as an error span, which is what SigNoz's
// error rates count (has_error).
func (rec *Record) spanStatus() *otlpStatus {
	if rec.Status < 400 {
		return nil
	}
	message := fmt.Sprintf("upstream returned HTTP %d", rec.Status)
	if rec.Trace.TransportError != "" {
		message = "upstream unreachable: " + rec.Trace.TransportError
	}
	return &otlpStatus{Code: spanStatusCodeErr, Message: message}
}

// attributes lists the span's attributes in key order: the proxy's own
// attribution on every span, the GenAI attributes on a call that names a
// model, and the error attributes on a failed one.
func (rec *Record) attributes(price Cost) []otlpAttribute {
	trace := rec.Trace
	attrs := []otlpAttribute{
		stringAttr(attrClient, rec.Client),
		stringAttr(attrUpstream, rec.Upstream),
		intAttr(attrResponseStatusCode, int64(rec.Status)),
	}
	if trace.Method != "" {
		attrs = append(attrs, stringAttr(attrRequestMethod, trace.Method))
	}
	if trace.Route != "" {
		attrs = append(attrs, stringAttr(attrRoute, trace.Route))
	}
	if trace.UpstreamRequestID != "" {
		attrs = append(attrs, stringAttr(attrUpstreamRequestID, trace.UpstreamRequestID))
	}
	if trace.Operation == "" {
		sort.Slice(attrs, func(i, j int) bool { return attrs[i].Key < attrs[j].Key })
		return attrs
	}

	attrs = append(attrs,
		stringAttr(attrOperation, trace.Operation),
		stringAttr(attrRequestModel, rec.Model),
		stringAttr(attrProvider, rec.Upstream),
		boolAttr(attrStream, rec.Stream),
		boolAttr(attrUsageMissing, rec.UsageMissing),
	)
	if !rec.UsageMissing {
		cost := BreakdownCost(rec.PromptTokens, rec.CachedTokens, rec.CompletionTokens, price)
		attrs = append(attrs,
			intAttr(attrInputTokens, int64(rec.PromptTokens)),
			intAttr(attrOutputTokens, int64(rec.CompletionTokens)),
			doubleAttr(attrCostInput, cost.Input),
			doubleAttr(attrCostCacheRead, cost.CachedInput),
			doubleAttr(attrCostOutput, cost.Output),
			doubleAttr(attrCostTotal, cost.Total),
		)
		if rec.CachedTokens > 0 {
			attrs = append(attrs, intAttr(attrCacheReadTokens, int64(rec.CachedTokens)))
		}
	}
	if rec.Stream && rec.TTFTMS >= 0 {
		attrs = append(attrs, doubleAttr(attrTimeToFirstToken, float64(rec.TTFTMS)/1000))
	}
	if trace.ResponseModel != "" {
		attrs = append(attrs, stringAttr(attrResponseModel, trace.ResponseModel))
	}
	if reason := rec.finishReason(); reason != "" {
		attrs = append(attrs, stringAttr(attrFinishReasons, reason))
	}
	if rec.Status >= 400 {
		errorType := strconv.Itoa(rec.Status)
		if trace.TransportError != "" {
			errorType = errorTypeUnreachable
		}
		attrs = append(attrs, stringAttr(attrErrorType, errorType))
	}
	sort.Slice(attrs, func(i, j int) bool { return attrs[i].Key < attrs[j].Key })
	return attrs
}

// finishReason is the span's gen_ai.response.finish_reasons: the reason the
// provider reported, or "error" for a call that failed before it could.
func (rec *Record) finishReason() string {
	if rec.Status >= 400 {
		return finishReasonError
	}
	return normalizeFinishReason(rec.Trace.FinishReason)
}

func stringAttr(key, value string) otlpAttribute {
	return otlpAttribute{Key: key, Value: otlpAnyValue{StringValue: &value}}
}

func boolAttr(key string, value bool) otlpAttribute {
	return otlpAttribute{Key: key, Value: otlpAnyValue{BoolValue: &value}}
}

// intAttr writes an integer attribute as OTLP/JSON requires: a decimal
// string holding an int64.
func intAttr(key string, value int64) otlpAttribute {
	text := strconv.FormatInt(value, 10)
	return otlpAttribute{Key: key, Value: otlpAnyValue{IntValue: &text}}
}

func doubleAttr(key string, value float64) otlpAttribute {
	return otlpAttribute{Key: key, Value: otlpAnyValue{DoubleValue: &value}}
}

// The OTLP/JSON wire types (the protobuf JSON mapping of
// opentelemetry.proto.trace.v1). 64-bit integers travel as decimal strings.
type otlpTraces struct {
	ResourceSpans []otlpResourceSpans `json:"resourceSpans"`
}

type otlpResourceSpans struct {
	Resource   otlpResource     `json:"resource"`
	ScopeSpans []otlpScopeSpans `json:"scopeSpans"`
}

type otlpResource struct {
	Attributes []otlpAttribute `json:"attributes"`
}

type otlpScopeSpans struct {
	Scope otlpScope   `json:"scope"`
	Spans []*otlpSpan `json:"spans"`
}

type otlpScope struct {
	Name string `json:"name"`
}

type otlpSpan struct {
	TraceID       string          `json:"traceId"`
	SpanID        string          `json:"spanId"`
	ParentSpanID  string          `json:"parentSpanId,omitempty"`
	Name          string          `json:"name"`
	Kind          int             `json:"kind"`
	StartUnixNano string          `json:"startTimeUnixNano"`
	EndUnixNano   string          `json:"endTimeUnixNano"`
	Attributes    []otlpAttribute `json:"attributes"`
	Status        *otlpStatus     `json:"status,omitempty"`
}

type otlpStatus struct {
	Code    int    `json:"code"`
	Message string `json:"message,omitempty"`
}

type otlpAttribute struct {
	Key   string       `json:"key"`
	Value otlpAnyValue `json:"value"`
}

type otlpAnyValue struct {
	StringValue *string  `json:"stringValue,omitempty"`
	IntValue    *string  `json:"intValue,omitempty"`
	DoubleValue *float64 `json:"doubleValue,omitempty"`
	BoolValue   *bool    `json:"boolValue,omitempty"`
}
