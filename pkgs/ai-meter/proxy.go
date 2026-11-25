package main

import (
	"bufio"
	"bytes"
	"crypto/subtle"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"
)

const maxMeteredBodyBytes = 128 << 20 // 128 MiB — long-context chat requests

// Proxy is the metering reverse proxy. It is transparent by contract:
// bodies pass through unmodified except the single opt-in
// stream_options.include_usage injection (configurable), which exists so
// streaming calls can be metered at all.
type Proxy struct {
	cfg      *Config
	registry *Registry
	ledger   *Ledger
	logger   *slog.Logger
	client   *http.Client
	spans    spanSink
}

// ProxyOption configures an optional part of a proxy.
type ProxyOption func(*Proxy)

// WithSpanSink sends every recorded call to sink, in addition to the metrics
// and the ledger.
func WithSpanSink(sink spanSink) ProxyOption {
	return func(p *Proxy) { p.spans = sink }
}

func NewProxy(cfg *Config, registry *Registry, ledger *Ledger, logger *slog.Logger, opts ...ProxyOption) *Proxy {
	p := &Proxy{
		cfg:      cfg,
		registry: registry,
		ledger:   ledger,
		logger:   logger,
		spans:    noSpans{},
		client: &http.Client{
			Transport: &http.Transport{
				MaxIdleConns:        32,
				MaxIdleConnsPerHost: 8,
				IdleConnTimeout:     90 * time.Second,
			},
			// No overall timeout: streamed completions run for minutes.
		},
	}
	for _, opt := range opts {
		opt(p)
	}
	return p
}

func (p *Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Health is served on the proxy port too (unauthenticated, cheap) so
	// consumers can readiness-check the exact endpoint they call.
	if r.URL.Path == "/health" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = io.WriteString(w, `{"status":"ok"}`)
		return
	}
	if !strings.HasPrefix(r.URL.Path, "/v1/") {
		writeError(w, http.StatusNotFound, "unknown route — expected /v1/<upstream>/<path>")
		return
	}
	rest := strings.TrimPrefix(r.URL.Path, "/v1/")
	upstreamName, subPath, ok := strings.Cut(rest, "/")
	if !ok || upstreamName == "" {
		writeError(w, http.StatusNotFound, "unknown route — expected /v1/<upstream>/<path>")
		return
	}
	upstream, found := p.findUpstream(upstreamName)
	if !found {
		writeError(w, http.StatusNotFound, fmt.Sprintf("unknown upstream %q (configured: %s)", upstreamName, strings.Join(p.cfg.UpstreamNames(), ", ")))
		return
	}

	client, ok := p.authenticate(r)
	if !ok {
		p.registry.Unauthorized()
		w.Header().Set("WWW-Authenticate", `Bearer realm="ai-meter"`)
		writeError(w, http.StatusUnauthorized, "missing or invalid client key")
		return
	}

	call := p.registry.BeginCall(client.Name, upstream.Name)
	defer call.End()

	if isMeteredPath(subPath) && r.Method == http.MethodPost {
		p.serveMetered(w, r, call, client, upstream, subPath, nil)
		return
	}
	if genai, ok := ParseGenAIPath(subPath); ok && r.Method == http.MethodPost {
		p.serveMetered(w, r, call, client, upstream, subPath, &genai)
		return
	}
	p.servePassthrough(w, r, client, upstream, subPath)
}

func (p *Proxy) findUpstream(name string) (Upstream, bool) {
	for _, up := range p.cfg.Upstreams {
		if up.Name == name {
			return up, true
		}
	}
	return Upstream{}, false
}

func (p *Proxy) authenticate(r *http.Request) (Client, bool) {
	auth := r.Header.Get("Authorization")
	var presented string
	if strings.HasPrefix(auth, "Bearer ") {
		presented = strings.TrimSpace(auth[len("Bearer "):])
	} else if k := r.Header.Get("X-Goog-Api-Key"); k != "" {
		// Native genai clients (crush's gemini provider) carry their proxy
		// key in Google's header — same key material, same constant-time
		// compare.
		presented = k
	} else {
		return Client{}, false
	}
	for _, cl := range p.cfg.Clients {
		if subtle.ConstantTimeCompare([]byte(presented), []byte(cl.key)) == 1 {
			return cl, true
		}
	}
	return Client{}, false
}

// isMeteredPath selects the JSON paths whose request carries a model and
// whose response carries usage: the token/cost metering surface.
func isMeteredPath(subPath string) bool {
	switch subPath {
	case "chat/completions", "completions", "embeddings", "responses":
		return true
	}
	return false
}

func (p *Proxy) serveMetered(w http.ResponseWriter, r *http.Request, call *Call, client Client, upstream Upstream, subPath string, genai *GenAIRequest) {
	rec := callRecord(r, client, upstream, subPath, time.Now())

	body, err := io.ReadAll(io.LimitReader(r.Body, maxMeteredBodyBytes+1))
	if err != nil {
		writeError(w, http.StatusBadRequest, "read request body: "+err.Error())
		return
	}
	if len(body) > maxMeteredBodyBytes {
		writeError(w, http.StatusRequestEntityTooLarge, "request body exceeds 128 MiB metering limit")
		return
	}

	info, _, err := ParseRequest(body)
	if err != nil {
		// Not a JSON body on a metered path: forward it anyway so the
		// proxy never becomes the reason a call fails — metered as a
		// request with unknown model and no token counts.
		p.forwardAndRecord(w, r, upstream, subPath, rec, body)
		return
	}
	if genai != nil {
		// Native genai call: model and streaming live in the URL, the
		// body stays untouched (no include_usage injection — the flag in
		// RequestInfo enforces that inside InjectStreamUsage).
		info.Model = genai.Model
		info.Stream = genai.Stream
		info.GenAI = true
	}
	call.SetModel(info.Model)
	rec.Model, rec.Stream = info.Model, info.Stream
	rec.Trace.Operation = genAIOperation(subPath, genai != nil)

	forwardBody := InjectStreamUsage(body, info, p.cfg.InjectStreamUsage)

	req, err := http.NewRequestWithContext(r.Context(), http.MethodPost, upstreamURL(upstream, subPath, r.URL.RawQuery), bytes.NewReader(forwardBody))
	if err != nil {
		writeError(w, http.StatusBadGateway, "build upstream request: "+err.Error())
		return
	}
	copyForwardHeaders(req, r)
	applyUpstreamAuth(req, upstream)
	req.ContentLength = int64(len(forwardBody))

	resp, err := p.client.Do(req)
	if err != nil {
		rec.Status, rec.UsageMissing = http.StatusBadGateway, true
		rec.Trace.TransportError = transportCause(err)
		p.record(rec)
		writeError(w, http.StatusBadGateway, "upstream unreachable: "+err.Error())
		return
	}
	defer func() { _ = resp.Body.Close() }()
	rec.Trace.UpstreamRequestID = upstreamRequestID(resp.Header)

	if info.Stream {
		p.streamResponse(w, resp, rec)
		return
	}
	p.bufferedResponse(w, resp, rec)
}

// callRecord opens the Record of one request with everything known before
// the upstream answers. The model stays unset until the request names one.
func callRecord(r *http.Request, client Client, upstream Upstream, route string, start time.Time) Record {
	return Record{
		Client:    client.Name,
		Upstream:  upstream.Name,
		StartedAt: start,
		Trace: CallTrace{
			Method: r.Method,
			Route:  route,
			Parent: traceContext(r.Header.Get("traceparent")),
		},
	}
}

// forwardAndRecord passes a non-JSON body through untouched and records
// the call with empty token counts.
func (p *Proxy) forwardAndRecord(w http.ResponseWriter, r *http.Request, upstream Upstream, subPath string, rec Record, body []byte) {
	req, err := http.NewRequestWithContext(r.Context(), r.Method, upstreamURL(upstream, subPath, r.URL.RawQuery), bytes.NewReader(body))
	if err != nil {
		writeError(w, http.StatusBadGateway, "build upstream request: "+err.Error())
		return
	}
	copyForwardHeaders(req, r)
	applyUpstreamAuth(req, upstream)
	req.ContentLength = int64(len(body))

	resp, err := p.client.Do(req)
	if err != nil {
		rec.Status, rec.UsageMissing = http.StatusBadGateway, true
		rec.Trace.TransportError = transportCause(err)
		p.record(rec)
		writeError(w, http.StatusBadGateway, "upstream unreachable: "+err.Error())
		return
	}
	defer func() { _ = resp.Body.Close() }()
	copyResponseHeaders(w, resp)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)

	rec.Trace.UpstreamRequestID = upstreamRequestID(resp.Header)
	rec.Status, rec.UsageMissing = resp.StatusCode, true
	p.record(rec)
}

func (p *Proxy) bufferedResponse(w http.ResponseWriter, resp *http.Response, rec Record) {
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxMeteredBodyBytes+1))
	if err != nil {
		rec.Status, rec.UsageMissing = resp.StatusCode, true
		p.record(rec)
		writeError(w, http.StatusBadGateway, "read upstream response: "+err.Error())
		return
	}

	usage, hasUsage := extractUsageAny(body)
	var meta responseMeta
	meta.observe(body)

	copyResponseHeaders(w, resp)
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(body)

	rec.Status, rec.UsageMissing = resp.StatusCode, !hasUsage
	rec.TTFTMS = -1
	rec.PromptTokens, rec.CompletionTokens, rec.CachedTokens = usage.PromptTokens, usage.CompletionTokens, usage.CachedTokens
	rec.Trace.ResponseModel, rec.Trace.FinishReason = meta.Model, meta.FinishReason
	p.record(rec)
}

func (p *Proxy) streamResponse(w http.ResponseWriter, resp *http.Response, rec Record) {
	flusher, _ := w.(http.Flusher)

	copyResponseHeaders(w, resp)
	w.Header().Set("X-Accel-Buffering", "no")
	w.WriteHeader(resp.StatusCode)

	usage := Usage{}
	hasUsage := false
	ttft := int64(-1) // no sample until the first byte is written
	var meta responseMeta

	reader := bufio.NewReaderSize(resp.Body, 64*1024)
	for {
		line, err := reader.ReadBytes('\n')
		if len(line) > 0 {
			if ttft < 0 {
				ttft = time.Since(rec.StartedAt).Milliseconds()
			}
			_, _ = w.Write(line)
			if flusher != nil {
				flusher.Flush()
			}
			trimmed := bytes.TrimSpace(line)
			if data, ok := bytes.CutPrefix(trimmed, []byte("data:")); ok {
				payload := bytes.TrimSpace(data)
				if !bytes.Equal(payload, []byte("[DONE]")) {
					if u, ok := ExtractUsageSSE(payload); ok {
						usage = u
						hasUsage = true
					} else if u, ok := ExtractGenAIUsageSSE(payload); ok {
						usage = u
						hasUsage = true
					} else {
						// Every other payload may name the serving model or
						// carry the finish reason; neither sits on a usage chunk.
						meta.observe(payload)
					}
				}
			}
		}
		if err != nil {
			if err != io.EOF {
				p.logger.Warn("stream read error", "upstream", rec.Upstream, "err", err)
			}
			break
		}
	}

	rec.Status, rec.UsageMissing = resp.StatusCode, !hasUsage
	rec.Stream = true
	rec.PromptTokens, rec.CompletionTokens, rec.CachedTokens = usage.PromptTokens, usage.CompletionTokens, usage.CachedTokens
	rec.TTFTMS = ttft
	rec.Trace.ResponseModel, rec.Trace.FinishReason = meta.Model, meta.FinishReason
	p.record(rec)
}

func (p *Proxy) servePassthrough(w http.ResponseWriter, r *http.Request, client Client, upstream Upstream, subPath string) {
	rec := callRecord(r, client, upstream, subPath, time.Now())

	req, err := http.NewRequestWithContext(r.Context(), r.Method, upstreamURL(upstream, subPath, r.URL.RawQuery), r.Body)
	if err != nil {
		writeError(w, http.StatusBadGateway, "build upstream request: "+err.Error())
		return
	}
	copyForwardHeaders(req, r)
	applyUpstreamAuth(req, upstream)

	resp, err := p.client.Do(req)
	if err != nil {
		rec.Status, rec.UsageMissing = http.StatusBadGateway, true
		rec.Trace.TransportError = transportCause(err)
		p.record(rec)
		writeError(w, http.StatusBadGateway, "upstream unreachable: "+err.Error())
		return
	}
	defer func() { _ = resp.Body.Close() }()

	copyResponseHeaders(w, resp)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)

	// Passthrough calls count as requests with no token attribution
	// (models listing, file uploads, legacy routes).
	rec.Trace.UpstreamRequestID = upstreamRequestID(resp.Header)
	rec.Status, rec.UsageMissing = resp.StatusCode, true
	p.record(rec)
}

// record folds one ended call into every output: the metrics, the ledger and
// the span sink. It completes the call's bookkeeping fields first, so each
// output sees the same call.
func (p *Proxy) record(rec Record) {
	rec.EndedAt = time.Now()
	rec.DurationMS = rec.EndedAt.Sub(rec.StartedAt).Milliseconds()
	rec.Path = "/v1/" + rec.Upstream + "/" + rec.Trace.Route
	rec.Model = modelName(rec.Model)
	if rec.Model == modelNone {
		// No model, no LLM call: the span leaves the GenAI attributes out.
		rec.Trace.Operation = ""
	}
	p.cfg.Price(&rec)

	p.registry.Record(rec)
	p.spans.Emit(&rec)
	if err := p.ledger.Append(rec); err != nil {
		p.registry.MeteringError()
		p.logger.Error("ledger append failed", "err", err, "client", rec.Client, "upstream", rec.Upstream)
	}
	if rec.UsageMissing && rec.Status < 400 {
		p.registry.MeteringError()
	}
}

// extractUsageAny reads usage from a buffered response body in either
// protocol shape (OpenAI "usage" first, native genai "usageMetadata"
// second — a body never carries both).
func extractUsageAny(body []byte) (Usage, bool) {
	if u, ok := ExtractUsageJSON(body); ok {
		return u, true
	}
	return ExtractGenAIUsageJSON(body)
}

// upstreamURL builds the forward target, preserving the client's query
// string (native genai streaming REQUIRES ?alt=sse — dropping it silently
// downgrades the response format).
func upstreamURL(upstream Upstream, subPath, rawQuery string) string {
	target := upstream.BaseURL + "/" + subPath
	if rawQuery != "" {
		target += "?" + rawQuery
	}
	return target
}

// applyUpstreamAuth presents the upstream key in the style that backend
// expects. Native Google endpoints reject Bearer API keys, so an
// x-goog-api-key upstream forwards via Google's header instead.
func applyUpstreamAuth(req *http.Request, upstream Upstream) {
	if upstream.AuthStyle == "x-goog-api-key" {
		req.Header.Set("X-Goog-Api-Key", upstream.APIKey)
		req.Header.Del("Authorization")
		return
	}
	req.Header.Set("Authorization", "Bearer "+upstream.APIKey)
}

// copyForwardHeaders mirrors request headers to the upstream request
// except hop-by-hop headers, client auth (both channels), and
// Accept-Encoding (the proxy must be able to read response bodies; it
// never asks for compression).
func copyForwardHeaders(dst, src *http.Request) {
	for name, values := range src.Header {
		switch name {
		case "Authorization", "X-Goog-Api-Key", "Host", "Accept-Encoding", "Connection",
			"Keep-Alive", "Te", "Trailer", "Transfer-Encoding", "Upgrade",
			"Proxy-Authenticate", "Proxy-Authorization":
			continue
		}
		for _, v := range values {
			dst.Header.Add(name, v)
		}
	}
	dst.Header.Set("Accept-Encoding", "identity")
}

func copyResponseHeaders(w http.ResponseWriter, resp *http.Response) {
	for name, values := range resp.Header {
		switch name {
		case "Connection", "Keep-Alive", "Te", "Trailer",
			"Transfer-Encoding", "Upgrade", "Content-Length":
			continue
		}
		for _, v := range values {
			w.Header().Add(name, v)
		}
	}
}

func writeError(w http.ResponseWriter, code int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_, _ = fmt.Fprintf(w, `{"error":{"message":%q,"type":"ai_meter_error","code":%d}}`, message, code)
}

// NewAdminHandler serves the admin plane: Prometheus metrics and health.
func NewAdminHandler(registry *Registry) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/metrics":
			w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
			_, _ = io.WriteString(w, registry.Render())
		case "/health":
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			_, _ = io.WriteString(w, `{"status":"ok"}`)
		default:
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusNotFound)
			_, _ = io.WriteString(w, `{"error":{"message":"unknown admin route","type":"ai_meter_error","code":404}}`)
		}
	})
}
