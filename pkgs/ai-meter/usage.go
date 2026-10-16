package main

import (
	"encoding/json"
	"fmt"
)

// Usage is the OpenAI usage block, extracted from both buffered JSON
// responses and the final SSE chunk of a stream.
type Usage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
	CachedTokens     int `json:"cached_tokens"`
}

// RequestInfo is what the proxy needs from a request body.
type RequestInfo struct {
	Model  string
	Stream bool
}

// ParseRequest decodes an OpenAI-compatible request body (chat/completions,
// completions, embeddings all share the relevant fields). It preserves every
// unknown field so the re-marshaled body is a faithful superset.
func ParseRequest(body []byte) (RequestInfo, []byte, error) {
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return RequestInfo{}, nil, fmt.Errorf("decode request body: %w", err)
	}

	info := RequestInfo{}
	if model, ok := payload["model"].(string); ok {
		info.Model = model
	}
	if stream, ok := payload["stream"].(bool); ok {
		info.Stream = stream
	}
	return info, body, nil
}

// InjectStreamUsage adds stream_options.include_usage to a streaming
// request when absent, so the upstream's final SSE chunk carries the usage
// block the proxy meters. Returns the original body when no change is
// needed (already present, not streaming, or injection disabled).
func InjectStreamUsage(body []byte, info RequestInfo, enabled bool) []byte {
	if !enabled || !info.Stream {
		return body
	}
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return body
	}
	opts, ok := payload["stream_options"].(map[string]any)
	if ok {
		if include, present := opts["include_usage"].(bool); present && include {
			return body
		}
	}
	if opts == nil {
		opts = map[string]any{}
	}
	opts["include_usage"] = true
	payload["stream_options"] = opts
	out, err := json.Marshal(payload)
	if err != nil {
		return body
	}
	return out
}

// ExtractUsageJSON pulls the usage block out of a buffered non-streaming
// response body. ok=false means the body carried no usage block (or is not
// JSON) — metering then records the request without token counts.
func ExtractUsageJSON(body []byte) (Usage, bool) {
	var resp struct {
		Usage *usageRaw `json:"usage"`
	}
	if err := json.Unmarshal(body, &resp); err != nil || resp.Usage == nil {
		return Usage{}, false
	}
	return resp.Usage.toUsage(), true
}

type usageRaw struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
	PromptDetails    *struct {
		CachedTokens int `json:"cached_tokens"`
	} `json:"prompt_tokens_details"`
}

func (u *usageRaw) toUsage() Usage {
	usage := Usage{
		PromptTokens:     u.PromptTokens,
		CompletionTokens: u.CompletionTokens,
		TotalTokens:      u.TotalTokens,
	}
	if u.PromptDetails != nil {
		usage.CachedTokens = u.PromptDetails.CachedTokens
	}
	if usage.TotalTokens == 0 {
		usage.TotalTokens = usage.PromptTokens + usage.CompletionTokens
	}
	return usage
}

// ExtractUsageSSE scans one SSE data line's JSON for a usage block.
// OpenAI-compatible servers emit it on the final chunk (before [DONE])
// when stream_options.include_usage was set.
func ExtractUsageSSE(data []byte) (Usage, bool) {
	var chunk struct {
		Usage *usageRaw `json:"usage"`
	}
	if err := json.Unmarshal(data, &chunk); err != nil || chunk.Usage == nil {
		return Usage{}, false
	}
	return chunk.Usage.toUsage(), true
}
