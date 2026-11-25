package main

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

// otlpCapture is a fake OTLP/HTTP endpoint: it records every export it
// receives and answers each with the configured status.
type otlpCapture struct {
	server *httptest.Server

	mu     sync.Mutex
	bodies [][]byte
	path   string
	status int
	block  chan struct{} // when set, every export waits for it to close
}

func newOTLPCapture(t *testing.T) *otlpCapture {
	t.Helper()
	c := &otlpCapture{status: http.StatusOK}
	c.server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		c.mu.Lock()
		c.bodies = append(c.bodies, body)
		c.path = r.URL.Path
		status := c.status
		c.mu.Unlock()
		if c.block != nil {
			<-c.block
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = w.Write([]byte(`{"partialSuccess":{}}`))
	}))
	t.Cleanup(c.server.Close)
	return c
}

func (c *otlpCapture) exports() [][]byte {
	c.mu.Lock()
	defer c.mu.Unlock()
	return append([][]byte(nil), c.bodies...)
}

func (c *otlpCapture) setStatus(status int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.status = status
}

// wireSpan is one span as it travelled the wire: attribute values are the
// raw OTLP/JSON value objects, so a test asserts the type as well as the
// content.
type wireSpan struct {
	name       string
	traceID    string
	spanID     string
	parentID   string
	kind       float64
	start, end string
	status     map[string]any
	attrs      map[string]any
}

type wireExport struct {
	resource map[string]any
	scope    string
	spans    []wireSpan
}

func decodeExports(t *testing.T, bodies [][]byte) wireExport {
	t.Helper()
	var out wireExport
	for i, body := range bodies {
		var envelope struct {
			ResourceSpans []struct {
				Resource struct {
					Attributes []wireAttribute `json:"attributes"`
				} `json:"resource"`
				ScopeSpans []struct {
					Scope struct {
						Name string `json:"name"`
					} `json:"scope"`
					Spans []struct {
						TraceID           string          `json:"traceId"`
						SpanID            string          `json:"spanId"`
						ParentSpanID      string          `json:"parentSpanId"`
						Name              string          `json:"name"`
						Kind              int             `json:"kind"`
						StartTimeUnixNano string          `json:"startTimeUnixNano"`
						EndTimeUnixNano   string          `json:"endTimeUnixNano"`
						Attributes        []wireAttribute `json:"attributes"`
						Status            map[string]any  `json:"status"`
					} `json:"spans"`
				} `json:"scopeSpans"`
			} `json:"resourceSpans"`
		}
		if err := json.Unmarshal(body, &envelope); err != nil {
			t.Fatalf("export %d is not OTLP/JSON: %v\n%s", i, err, body)
		}
		if len(envelope.ResourceSpans) != 1 || len(envelope.ResourceSpans[0].ScopeSpans) != 1 {
			t.Fatalf("export %d should carry one resource and one scope:\n%s", i, body)
		}
		resource := envelope.ResourceSpans[0]
		if out.resource == nil {
			out.resource = attrMap(resource.Resource.Attributes)
			out.scope = resource.ScopeSpans[0].Scope.Name
		}
		for _, span := range resource.ScopeSpans[0].Spans {
			out.spans = append(out.spans, wireSpan{
				name:     span.Name,
				traceID:  span.TraceID,
				spanID:   span.SpanID,
				parentID: span.ParentSpanID,
				kind:     float64(span.Kind),
				start:    span.StartTimeUnixNano,
				end:      span.EndTimeUnixNano,
				status:   span.Status,
				attrs:    attrMap(span.Attributes),
			})
		}
	}
	return out
}

type wireAttribute struct {
	Key   string         `json:"key"`
	Value map[string]any `json:"value"`
}

func attrMap(attrs []wireAttribute) map[string]any {
	out := make(map[string]any, len(attrs))
	for _, attr := range attrs {
		out[attr.Key] = attr.Value
	}
	return out
}

func wireString(t *testing.T, attrs map[string]any, key string) string {
	t.Helper()
	value, ok := attrs[key].(map[string]any)["stringValue"].(string)
	if !ok {
		t.Fatalf("attribute %q is not a string on the wire: %v", key, attrs[key])
	}
	return value
}

func wireInt(t *testing.T, attrs map[string]any, key string) int64 {
	t.Helper()
	text, ok := attrs[key].(map[string]any)["intValue"].(string)
	if !ok {
		t.Fatalf("attribute %q is not an int64 string on the wire: %v", key, attrs[key])
	}
	value, err := strconv.ParseInt(text, 10, 64)
	if err != nil {
		t.Fatalf("attribute %q: %v", key, err)
	}
	return value
}

func wireFloat(t *testing.T, attrs map[string]any, key string) float64 {
	t.Helper()
	value, ok := attrs[key].(map[string]any)["doubleValue"].(float64)
	if !ok {
		t.Fatalf("attribute %q is not a double on the wire: %v", key, attrs[key])
	}
	return value
}

func wireBool(t *testing.T, attrs map[string]any, key string) bool {
	t.Helper()
	value, ok := attrs[key].(map[string]any)["boolValue"].(bool)
	if !ok {
		t.Fatalf("attribute %q is not a bool on the wire: %v", key, attrs[key])
	}
	return value
}

func wireMissing(t *testing.T, attrs map[string]any, key string) {
	t.Helper()
	if _, present := attrs[key]; present {
		t.Fatalf("attribute %q should not be on the wire: %v", key, attrs[key])
	}
}

// exported reads one outcome of ai_meter_spans_exported_total.
func exported(t *testing.T, exposition, outcome string) float64 {
	t.Helper()
	for line := range strings.SplitSeq(exposition, "\n") {
		if strings.HasPrefix(line, `ai_meter_spans_exported_total{outcome="`+outcome+`"} `) {
			value, err := strconv.ParseFloat(line[strings.LastIndexByte(line, ' ')+1:], 64)
			if err != nil {
				t.Fatalf("parse %q: %v", line, err)
			}
			return value
		}
	}
	t.Fatalf("no %q series in exposition:\n%s", outcome, exposition)
	return 0
}

// awaitExported polls until at least want spans reached an outcome; the
// worker posts asynchronously.
func awaitExported(t *testing.T, registry *Registry, outcome string, want float64) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for exported(t, registry.Render(), outcome) < want {
		if time.Now().After(deadline) {
			t.Fatalf("fewer than %v spans %s:\n%s", want, outcome, registry.Render())
		}
		time.Sleep(5 * time.Millisecond)
	}
}

// shutdownExporter stops the exporter and returns once every queued span was
// posted, so the counters are final.
func shutdownExporter(t *testing.T, spans *SpanExporter) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	spans.Shutdown(ctx)
}

// chatCall is a recorded streaming chat call with every field set.
func chatCall(status int) Record {
	now := time.Now()
	return Record{
		Client:           "crush",
		Upstream:         "zai",
		Model:            "glm-5.4",
		Status:           status,
		Stream:           true,
		PromptTokens:     100,
		CompletionTokens: 50,
		CachedTokens:     20,
		TTFTMS:           420,
		StartedAt:        now.Add(-1500 * time.Millisecond),
		EndedAt:          now,
		Trace: CallTrace{
			Method:            "POST",
			Route:             "chat/completions",
			Operation:         "chat",
			ResponseModel:     "glm-5.4",
			FinishReason:      "stop",
			UpstreamRequestID: "req-1",
		},
	}
}

// exporterCfg is the config of an exporter under test.
func exporterCfg(endpoint string) *Config {
	return &Config{
		OTLPEndpoint:          endpoint,
		DeploymentEnvironment: "production",
		Costs:                 map[string]Cost{"glm-5.4": {Input: 2, Output: 4, CachedInput: 0.5}},
	}
}

func TestSpanCarriesTheGenAIAttributesOfASuccessfulCall(t *testing.T) {
	capture := newOTLPCapture(t)
	registry := NewRegistry()
	spans := NewSpanExporter(exporterCfg(capture.server.URL), registry, slog.Default())

	call := chatCall(http.StatusOK)
	spans.Emit(&call)
	shutdownExporter(t, spans)

	if got := exported(t, registry.Render(), "ok"); got != 1 {
		t.Fatalf("exported %v spans ok, want 1", got)
	}
	export := decodeExports(t, capture.exports())
	if len(export.spans) != 1 {
		t.Fatalf("want 1 span, got %d", len(export.spans))
	}
	if wireString(t, export.resource, "service.name") != "ai-meter" ||
		wireString(t, export.resource, "deployment.environment") != "production" {
		t.Fatalf("resource attributes wrong: %v", export.resource)
	}
	if export.scope != "github.com/larsartmann/systemnix/ai-meter" {
		t.Fatalf("scope name %q", export.scope)
	}

	span := export.spans[0]
	if span.name != "chat glm-5.4" || span.kind != 3 {
		t.Fatalf("name %q kind %v", span.name, span.kind)
	}
	if len(span.traceID) != 32 || len(span.spanID) != 16 || span.parentID != "" {
		t.Fatalf("ids wrong: trace %q span %q parent %q", span.traceID, span.spanID, span.parentID)
	}
	start, _ := strconv.ParseInt(span.start, 10, 64)
	end, _ := strconv.ParseInt(span.end, 10, 64)
	if math.Abs(float64(end-start-1_500_000_000)) > 5_000_000 {
		t.Fatalf("span duration %d ns, want about 1.5 s", end-start)
	}
	if span.status != nil {
		t.Fatalf("a successful call carries no error status: %v", span.status)
	}

	// The GenAI attributes SigNoz's AI views read, in the OTLP type each
	// needs: tokens as int64, cost and time as doubles.
	attrs := span.attrs
	for key, want := range map[string]string{
		attrOperation:     "chat",
		attrRequestModel:  "glm-5.4",
		attrProvider:      "zai",
		attrResponseModel: "glm-5.4",
		attrFinishReasons: "stop",
	} {
		if got := wireString(t, attrs, key); got != want {
			t.Fatalf("%s = %q, want %q", key, got, want)
		}
	}
	if wireInt(t, attrs, attrInputTokens) != 100 || wireInt(t, attrs, attrOutputTokens) != 50 || wireInt(t, attrs, attrCacheReadTokens) != 20 {
		t.Fatalf("token attributes wrong: %v", attrs)
	}
	if got := wireFloat(t, attrs, attrTimeToFirstToken); got != 0.42 {
		t.Fatalf("time to first token %v s, want 0.42", got)
	}
	// 80 billable prompt tokens at 2, 20 cached at 0.5, 50 completion at 4,
	// per million: the same price the cost counter shows.
	for key, want := range map[string]float64{
		attrCostInput:     0.00016,
		attrCostCacheRead: 0.00001,
		attrCostOutput:    0.0002,
		attrCostTotal:     0.00037,
	} {
		if got := wireFloat(t, attrs, key); math.Abs(got-want) > 1e-12 {
			t.Fatalf("%s = %v, want %v", key, got, want)
		}
	}

	// The proxy's own attribution and the HTTP attributes.
	for key, want := range map[string]string{
		attrClient:            "crush",
		attrUpstream:          "zai",
		attrRoute:             "chat/completions",
		attrRequestMethod:     "POST",
		attrUpstreamRequestID: "req-1",
	} {
		if got := wireString(t, attrs, key); got != want {
			t.Fatalf("%s = %q, want %q", key, got, want)
		}
	}
	if wireInt(t, attrs, attrResponseStatusCode) != 200 || !wireBool(t, attrs, attrStream) || wireBool(t, attrs, attrUsageMissing) {
		t.Fatalf("status, stream or usage attributes wrong: %v", attrs)
	}
	wireMissing(t, attrs, attrErrorType)
}

func TestSpanMarksFailedCallsAsErrors(t *testing.T) {
	tests := []struct {
		name          string
		status        int
		transportErr  string
		wantErrorType string
		wantMessage   string
	}{
		{"HTTP error", http.StatusTooManyRequests, "", "429", "upstream returned HTTP 429"},
		{"upstream never answered", http.StatusBadGateway, "connection refused", errorTypeUnreachable, "upstream unreachable: connection refused"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			capture := newOTLPCapture(t)
			registry := NewRegistry()
			spans := NewSpanExporter(exporterCfg(capture.server.URL), registry, slog.Default())

			call := chatCall(test.status)
			call.UsageMissing = true
			call.PromptTokens, call.CompletionTokens, call.CachedTokens = 0, 0, 0
			call.Trace.TransportError = test.transportErr
			spans.Emit(&call)
			shutdownExporter(t, spans)

			span := decodeExports(t, capture.exports()).spans[0]
			if code, _ := span.status["code"].(float64); code != 2 {
				t.Fatalf("a failed call is an error span, got status %v", span.status)
			}
			if message, _ := span.status["message"].(string); message != test.wantMessage {
				t.Fatalf("status message %q, want %q", message, test.wantMessage)
			}
			attrs := span.attrs
			if got := wireString(t, attrs, attrErrorType); got != test.wantErrorType {
				t.Fatalf("error.type = %q, want %q", got, test.wantErrorType)
			}
			if got := wireString(t, attrs, attrFinishReasons); got != "error" {
				t.Fatalf("finish reason of a failed call = %q, want error", got)
			}
			if got := wireInt(t, attrs, attrResponseStatusCode); got != int64(test.status) {
				t.Fatalf("status code attribute %d, want %d", got, test.status)
			}
			// No usage was reported, so no token or cost attribute may
			// claim one.
			for _, key := range []string{attrInputTokens, attrOutputTokens, attrCostTotal, attrCostInput} {
				wireMissing(t, attrs, key)
			}
		})
	}
}

func TestSpanOfACallWithoutModelIsNotAnLLMCall(t *testing.T) {
	capture := newOTLPCapture(t)
	registry := NewRegistry()
	spans := NewSpanExporter(exporterCfg(capture.server.URL), registry, slog.Default())

	call := chatCall(http.StatusOK)
	call.Model, call.UsageMissing = "none", true
	call.PromptTokens, call.CompletionTokens, call.CachedTokens = 0, 0, 0
	call.Trace = CallTrace{Method: http.MethodGet, Route: "models"}
	spans.Emit(&call)
	shutdownExporter(t, spans)

	span := decodeExports(t, capture.exports()).spans[0]
	if span.name != "GET models" {
		t.Fatalf("span name %q", span.name)
	}
	for key := range span.attrs {
		if strings.HasPrefix(key, "gen_ai.") || strings.HasPrefix(key, "signoz.") {
			t.Fatalf("a call without a model carries %q: %v", key, span.attrs)
		}
	}
	if wireString(t, span.attrs, attrClient) != "crush" || wireInt(t, span.attrs, attrResponseStatusCode) != 200 {
		t.Fatalf("attribution attributes missing: %v", span.attrs)
	}
}

func TestSpanContinuesTheCallersSampledTrace(t *testing.T) {
	const (
		traceID = "4bf92f3577b34da6a3ce929d0e0e4736"
		spanID  = "00f067aa0ba902b7"
	)
	tests := []struct {
		name        string
		traceparent string
		wantChild   bool
	}{
		{"sampled", "00-" + traceID + "-" + spanID + "-01", true},
		{"sampled with other flags", "00-" + traceID + "-" + spanID + "-ff", true},
		{"not sampled", "00-" + traceID + "-" + spanID + "-00", false},
		{"zero trace id", "00-00000000000000000000000000000000-" + spanID + "-01", false},
		{"uppercase hex", "00-4BF92F3577B34DA6A3CE929D0E0E4736-" + spanID + "-01", false},
		{"wrong version", "01-" + traceID + "-" + spanID + "-01", false},
		{"garbage", "not-a-traceparent", false},
		{"empty", "", false},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			capture := newOTLPCapture(t)
			registry := NewRegistry()
			spans := NewSpanExporter(exporterCfg(capture.server.URL), registry, slog.Default())

			call := chatCall(http.StatusOK)
			call.Trace.Parent = traceContext(test.traceparent)
			spans.Emit(&call)
			shutdownExporter(t, spans)

			span := decodeExports(t, capture.exports()).spans[0]
			if !test.wantChild {
				if span.traceID == traceID || span.parentID != "" || len(span.traceID) != 32 {
					t.Fatalf("should start a trace of its own: trace %q parent %q", span.traceID, span.parentID)
				}
				return
			}
			if span.traceID != traceID || span.parentID != spanID || span.spanID == spanID {
				t.Fatalf("should continue the caller's trace: trace %q parent %q span %q", span.traceID, span.parentID, span.spanID)
			}
		})
	}
}

func TestSpanExporterCountsEveryOutcome(t *testing.T) {
	t.Run("endpoint rejects the batch", func(t *testing.T) {
		capture := newOTLPCapture(t)
		capture.setStatus(http.StatusInternalServerError)
		registry := NewRegistry()
		spans := NewSpanExporter(exporterCfg(capture.server.URL), registry, slog.Default())

		call := chatCall(http.StatusOK)
		for range 3 {
			spans.Emit(&call)
		}
		shutdownExporter(t, spans)

		out := registry.Render()
		if exported(t, out, "failed") != 3 || exported(t, out, "ok") != 0 || exported(t, out, "dropped") != 0 {
			t.Fatalf("outcomes wrong:\n%s", out)
		}
	})

	t.Run("a full queue drops the span and says so", func(t *testing.T) {
		capture := newOTLPCapture(t)
		release := make(chan struct{})
		capture.block = release
		registry := NewRegistry()
		spans := NewSpanExporter(exporterCfg(capture.server.URL), registry, slog.Default())

		// The worker holds one batch inside the blocked post; the queue
		// takes spanQueueCapacity more, and the rest cannot be kept.
		const emitted = spanQueueCapacity + spanBatchMax + 10
		call := chatCall(http.StatusOK)
		for range emitted {
			spans.Emit(&call)
		}
		out := registry.Render()
		dropped := exported(t, out, "dropped")
		if dropped <= 0 {
			t.Fatalf("nothing was dropped with the queue full:\n%s", out)
		}
		if got := exported(t, out, "failed"); got != 0 {
			t.Fatalf("a dropped span is not a failed one:\n%s", out)
		}

		// Shutdown drains what was queued once the endpoint answers.
		close(release)
		shutdownExporter(t, spans)
		out = registry.Render()
		if ok := exported(t, out, "ok"); ok != float64(emitted)-dropped {
			t.Fatalf("ok = %v, want %v (every span that was kept):\n%s", ok, float64(emitted)-dropped, out)
		}
		if got := exported(t, out, "dropped"); got != dropped {
			t.Fatalf("dropped changed across shutdown: %v, want %v", got, dropped)
		}
	})

	t.Run("a record without times cannot become a span", func(t *testing.T) {
		capture := newOTLPCapture(t)
		registry := NewRegistry()
		spans := NewSpanExporter(exporterCfg(capture.server.URL), registry, slog.Default())

		spans.Emit(&Record{Client: "crush", Upstream: "zai", Model: "glm-5.4", Status: 200})
		shutdownExporter(t, spans)

		if exported(t, registry.Render(), "failed") != 1 || len(capture.exports()) != 0 {
			t.Fatalf("a record without times must fail before any export:\n%s", registry.Render())
		}
	})
}

func TestSpanExporterAppendsTheTracesPathToABaseURL(t *testing.T) {
	tests := map[string]string{
		"http://127.0.0.1:4318":           "http://127.0.0.1:4318/v1/traces",
		"http://127.0.0.1:4318/":          "http://127.0.0.1:4318/v1/traces",
		"http://collector.internal/v1/traces": "http://collector.internal/v1/traces",
	}
	for endpoint, want := range tests {
		if got := otlpTracesURL(endpoint); got != want {
			t.Errorf("otlpTracesURL(%q) = %q, want %q", endpoint, got, want)
		}
	}

	capture := newOTLPCapture(t)
	spans := NewSpanExporter(exporterCfg(capture.server.URL), NewRegistry(), slog.Default())
	spans.Emit(&chatCall(http.StatusOK))
	shutdownExporter(t, spans)
	if capture.path != "/v1/traces" {
		t.Fatalf("export posted to %q, want /v1/traces", capture.path)
	}
}

func TestOTLPEndpointIsValidatedAtLoad(t *testing.T) {
	dir := t.TempDir()
	keyFile := filepath.Join(dir, "crush.key")
	if err := os.WriteFile(keyFile, []byte("test-key-1"), 0o600); err != nil {
		t.Fatal(err)
	}
	for endpoint, wantErr := range map[string]bool{
		"http://127.0.0.1:4318":         false,
		"https://collector.example/v1/traces": false,
		"":                              false,
		"127.0.0.1:4318":                true,
		"grpc://127.0.0.1:4317":         true,
		"http://":                      true,
	} {
		body := `{"listen":"127.0.0.1:0","metrics_listen":"127.0.0.1:0","ledger_path":"` + filepath.Join(dir, "usage.jsonl") +
			`","clients":[{"name":"crush","key_file":"` + keyFile + `"}],"upstreams":[{"name":"zai","base_url":"https://example.test"}],"otlp_endpoint":"` + endpoint + `"}`
		path := filepath.Join(dir, "config.json")
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		_, err := LoadConfig(path)
		if wantErr && (err == nil || !strings.Contains(err.Error(), "otlp_endpoint")) {
			t.Errorf("otlp_endpoint %q: error = %v, want one naming otlp_endpoint", endpoint, err)
		}
		if !wantErr && err != nil {
			t.Errorf("otlp_endpoint %q: %v", endpoint, err)
		}
	}
}

func TestGenAIOperationNamesTheMeteredRoutes(t *testing.T) {
	tests := []struct {
		subPath string
		native  bool
		want    string
	}{
		{"chat/completions", false, "chat"},
		{"responses", false, "chat"},
		{"completions", false, "text_completion"},
		{"embeddings", false, "embeddings"},
		{"v1beta/models/gemini-2.5-flash:streamGenerateContent", true, "generate_content"},
		{"models", false, ""},
	}
	for _, test := range tests {
		if got := genAIOperation(test.subPath, test.native); got != test.want {
			t.Errorf("genAIOperation(%q, native %v) = %q, want %q", test.subPath, test.native, got, test.want)
		}
	}
}

func TestResponseMetaReadsBothProtocolFamilies(t *testing.T) {
	tests := []struct {
		name        string
		payloads    []string
		wantModel   string
		wantReason  string
	}{
		{"OpenAI chat completion", []string{`{"model":"glm-5.4","choices":[{"finish_reason":"stop","message":{}}]}`}, "glm-5.4", "stop"},
		{"OpenAI stream: model first, reason later", []string{
			`{"model":"glm-5.4","choices":[{"delta":{"content":"a"},"finish_reason":null}]}`,
			`{"model":"glm-5.4","choices":[{"delta":{},"finish_reason":"tool_calls"}]}`,
			`{"model":"glm-5.4","choices":[],"usage":{"prompt_tokens":1}}`,
		}, "glm-5.4", "tool_call"},
		{"Gemini generateContent", []string{`{"modelVersion":"gemini-2.5-flash","candidates":[{"finishReason":"STOP"}]}`}, "gemini-2.5-flash", "stop"},
		{"Gemini cut off", []string{`{"modelVersion":"gemini-2.5-flash","candidates":[{"finishReason":"MAX_TOKENS"}]}`}, "gemini-2.5-flash", "length"},
		{"Responses API completed", []string{`{"model":"m","status":"completed","output":[]}`}, "m", "stop"},
		{"Responses API ran out of tokens", []string{`{"model":"m","status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output":[]}`}, "m", "length"},
		{"a plain error body", []string{`{"error":{"code":"1113","message":"no balance"}}`}, "", ""},
		{"not JSON", []string{`<html>`}, "", ""},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			var meta responseMeta
			for _, payload := range test.payloads {
				meta.observe([]byte(payload))
			}
			if meta.Model != test.wantModel || meta.FinishReason != test.wantReason {
				t.Fatalf("got model %q reason %q, want %q %q", meta.Model, meta.FinishReason, test.wantModel, test.wantReason)
			}
		})
	}
}

// exportingStack is a testStack whose proxy exports spans to a capture.
type exportingStack struct {
	*testStack
	capture *otlpCapture
	spans   *SpanExporter
}

// ExportedSpans returns every span exported so far.
func (s *exportingStack) exportedSpans(t *testing.T) []wireSpan {
	t.Helper()
	awaitExported(t, s.registry, "ok", 1)
	return decodeExports(t, s.capture.exports()).spans
}

func newExportingStack(t *testing.T) *exportingStack {
	t.Helper()
	stack := newTestStack(t, map[string]Cost{"m": {Input: 2, Output: 4, CachedInput: 0.5}})
	s := &exportingStack{testStack: stack, capture: newOTLPCapture(t)}
	s.spans = NewSpanExporter(exporterCfg(s.capture.server.URL), stack.registry, slog.Default())
	proxy := NewProxy(stack.cfg, stack.registry, stack.ledger, slog.Default(), WithSpanSink(s.spans))
	stack.proxy.Close()
	stack.proxy = httptest.NewServer(proxy)
	t.Cleanup(stack.proxy.Close)
	t.Cleanup(func() { shutdownExporter(t, s.spans) })
	return s
}

func TestProxyExportsTheSpanOfEachKindOfCall(t *testing.T) {
	s := newExportingStack(t)

	t.Run("streaming chat", func(t *testing.T) {
		resp := s.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m","stream":true,"messages":[]}`)
		defer func() { _ = resp.Body.Close() }()
		if _, err := io.Copy(io.Discard, resp.Body); err != nil {
			t.Fatal(err)
		}

		spans := s.exportedSpans(t)
		if len(spans) == 0 {
			t.Fatal("no span exported")
		}
		span := spans[len(spans)-1]
		if span.name != "chat m" {
			t.Fatalf("span name %q", span.name)
		}
		// The test upstream's stream names neither model nor finish
		// reason: the span says so by leaving both out, never by guessing.
		wireMissing(t, span.attrs, attrResponseModel)
		wireMissing(t, span.attrs, attrFinishReasons)
		if wireInt(t, span.attrs, attrInputTokens) != 12 || wireInt(t, span.attrs, attrOutputTokens) != 4 || wireInt(t, span.attrs, attrCacheReadTokens) != 2 {
			t.Fatalf("token attributes wrong: %v", span.attrs)
		}
		if wireFloat(t, span.attrs, attrTimeToFirstToken) < 0 || wireFloat(t, span.attrs, attrTimeToFirstToken) > 30 {
			t.Fatalf("time to first token %v s is not a plausible sample", span.attrs[attrTimeToFirstToken])
		}
		if !wireBool(t, span.attrs, attrStream) || wireBool(t, span.attrs, attrUsageMissing) {
			t.Fatalf("stream or usage attribute wrong: %v", span.attrs)
		}
	})

	t.Run("buffered chat", func(t *testing.T) {
		before := len(decodeExports(t, s.capture.exports()).spans)
		resp := s.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m","messages":[]}`)
		defer func() { _ = resp.Body.Close() }()
		if _, err := io.Copy(io.Discard, resp.Body); err != nil {
			t.Fatal(err)
		}

		spans := s.exportedSpans(t)
		if len(spans) <= before {
			t.Fatalf("no span exported: %d", len(spans))
		}
		span := spans[len(spans)-1]
		if wireString(t, span.attrs, attrResponseModel) != "m" {
			t.Fatalf("the test upstream answers with the requested model: %v", span.attrs[attrResponseModel])
		}
		if wireBool(t, span.attrs, attrStream) {
			t.Fatal("a buffered call is not a stream")
		}
		wireMissing(t, span.attrs, attrTimeToFirstToken)
		// (100-20)*2/1e6 + 20*0.5/1e6 + 50*4/1e6, the cost counter's value.
		if got := wireFloat(t, span.attrs, attrCostTotal); math.Abs(got-0.00037) > 1e-12 {
			t.Fatalf("span cost %v, want 0.00037", got)
		}
	})

	t.Run("passthrough without a model", func(t *testing.T) {
		before := len(decodeExports(t, s.capture.exports()).spans)
		req, _ := http.NewRequest(http.MethodGet, s.proxy.URL+"/v1/fake/models", nil)
		req.Header.Set("Authorization", "Bearer test-key-1")
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		_ = resp.Body.Close()

		spans := s.exportedSpans(t)
		if len(spans) <= before {
			t.Fatalf("no span exported: %d", len(spans))
		}
		span := spans[len(spans)-1]
		if span.name != "GET models" || len(span.parentID) != 0 {
			t.Fatalf("span %q parent %q", span.name, span.parentID)
		}
		for key := range span.attrs {
			if strings.HasPrefix(key, "gen_ai.") {
				t.Fatalf("a model listing is not an LLM call: %v", span.attrs)
			}
		}
	})

	t.Run("a non-JSON body on a metered path", func(t *testing.T) {
		before := len(decodeExports(t, s.capture.exports()).spans)
		resp := s.post("/v1/fake/chat/completions", "test-key-1", `not json`)
		_ = resp.Body.Close()

		spans := s.exportedSpans(t)
		if len(spans) <= before {
			t.Fatalf("no span exported: %d", len(spans))
		}
		span := spans[len(spans)-1]
		if span.name != "POST chat/completions" {
			t.Fatalf("span name %q: a call without a model is named after its route", span.name)
		}
		wireMissing(t, span.attrs, attrRequestModel)
	})
}

// richUpstream answers the way real providers do: every SSE chunk names the
// serving model, the last content chunk carries the finish reason, and the
// response carries a request id.
func richUpstream() *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.ReadAll(r.Body)
		w.Header().Set("X-Request-Id", "req_7f3")
		w.Header().Set("Content-Type", "text/event-stream")
		flusher := w.(http.Flusher)
		for _, chunk := range []string{
			`data: {"id":"c1","model":"glm-5.4-20261120","choices":[{"delta":{"content":"Hel"},"finish_reason":null}]}`,
			`data: {"id":"c1","model":"glm-5.4-20261120","choices":[{"delta":{},"finish_reason":"length"}]}`,
			`data: {"id":"c1","model":"glm-5.4-20261120","choices":[],"usage":{"prompt_tokens":12,"completion_tokens":4,"total_tokens":16}}`,
			`data: [DONE]`,
		} {
			_, _ = io.WriteString(w, chunk+"\n\n")
			flusher.Flush()
		}
	}))
}

func TestProxySpanNamesTheModelThatServedAndWhyItStopped(t *testing.T) {
	upstream := richUpstream()
	t.Cleanup(upstream.Close)

	s := newExportingStack(t)
	s.cfg.Upstreams[0].BaseURL = upstream.URL

	// The caller instrumented its own trace and sampled it: the LLM call
	// joins it as the client span the caller's own SDK would have made.
	req, _ := http.NewRequest(http.MethodPost, s.proxy.URL+"/v1/fake/chat/completions",
		strings.NewReader(`{"model":"glm-5.4","stream":true,"messages":[]}`))
	req.Header.Set("Authorization", "Bearer test-key-1")
	req.Header.Set("traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	_ = resp.Body.Close()

	spans := s.exportedSpans(t)
	span := spans[len(spans)-1]
	attrs := span.attrs
	for key, want := range map[string]string{
		attrRequestModel:     "glm-5.4",
		attrResponseModel:    "glm-5.4-20261120", // what the upstream says served it
		attrFinishReasons:    "length",           // and why it stopped
		attrUpstreamRequestID: "req_7f3",
	} {
		if got := wireString(t, attrs, key); got != want {
			t.Fatalf("%s = %q, want %q", key, got, want)
		}
	}
	if span.traceID != "4bf92f3577b34da6a3ce929d0e0e4736" || span.parentID != "00f067aa0ba902b7" {
		t.Fatalf("the span did not join the caller's trace: %q parent %q", span.traceID, span.parentID)
	}
	if span.status != nil {
		t.Fatalf("a complete call is not an error: %v", span.status)
	}
}

func TestProxyWithoutAnEndpointExportsNothing(t *testing.T) {
	s := newTestStack(t, nil)

	resp := s.post("/v1/fake/chat/completions", "test-key-1", `{"model":"m"}`)
	_ = resp.Body.Close()

	// The outcome series exist at zero, so a rate over them never meets
	// an absent series.
	out := s.registry.Render()
	if exported(t, out, "ok") != 0 || exported(t, out, "failed") != 0 || exported(t, out, "dropped") != 0 {
		t.Fatalf("a proxy without an endpoint exports nothing:\n%s", out)
	}
}

func TestSpanCostBucketsSumToTheCostCounter(t *testing.T) {
	breakdown := BreakdownCost(100, 20, 50, Cost{Input: 2, Output: 4, CachedInput: 0.5})
	if math.Abs(breakdown.Input+breakdown.CachedInput+breakdown.Output-breakdown.Total) > 1e-15 {
		t.Fatalf("buckets %v do not sum to the total %v", breakdown, breakdown.Total)
	}
	if breakdown.Total != EstimateCost(100, 20, 50, Cost{Input: 2, Output: 4, CachedInput: 0.5}) {
		t.Fatal("the total is not the cost counter's value")
	}
}
