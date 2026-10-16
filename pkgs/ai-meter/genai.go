package main

// Native Google GenAI (Gemini) protocol adapter.
//
// crush's gemini provider rides google-genai-sdk NATIVE transport even with
// a custom --base-url (probe 2026-10-17: POST
// {base}/v1beta/models/<model>:streamGenerateContent?alt=sse, auth via
// X-Goog-Api-Key, genai-format bodies). These calls do not speak OpenAI
// shapes, so this file owns everything protocol-specific about them:
// model-from-URL parsing, stream-from-method detection, and usageMetadata
// extraction. The OpenAI paths in usage.go stay untouched.

import (
	"encoding/json"
	"regexp"
)

// genaiPathRe matches native generate-content routes across API versions
// (v1, v1beta, v1alpha…): the model lives in the URL, not the body.
var genaiPathRe = regexp.MustCompile(`^v[0-9]+[a-z]*[0-9]*/models/([^/:]+):(streamGenerateContent|generateContent)$`)

// GenAIRequest is the native-protocol counterpart of RequestInfo.
type GenAIRequest struct {
	Model  string
	Stream bool
}

// ParseGenAIPath recognizes a native generate-content sub-path and derives
// model and streaming mode from it. ok=false for everything else (OpenAI
// paths, countTokens, file API, …) — those keep their existing handling.
func ParseGenAIPath(subPath string) (GenAIRequest, bool) {
	m := genaiPathRe.FindStringSubmatch(subPath)
	if m == nil {
		return GenAIRequest{}, false
	}
	return GenAIRequest{Model: m[1], Stream: m[2] == "streamGenerateContent"}, true
}

// usageMetadataRaw is the native usage block. thoughtsTokenCount is billed
// as output, so it folds into completion tokens.
type usageMetadataRaw struct {
	PromptTokenCount        int `json:"promptTokenCount"`
	CandidatesTokenCount    int `json:"candidatesTokenCount"`
	ThoughtsTokenCount      int `json:"thoughtsTokenCount"`
	CachedContentTokenCount int `json:"cachedContentTokenCount"`
	TotalTokenCount         int `json:"totalTokenCount"`
}

func (u *usageMetadataRaw) toUsage() Usage {
	usage := Usage{
		PromptTokens:     u.PromptTokenCount,
		CompletionTokens: u.CandidatesTokenCount + u.ThoughtsTokenCount,
		TotalTokens:      u.TotalTokenCount,
		CachedTokens:     u.CachedContentTokenCount,
	}
	if usage.TotalTokens == 0 {
		usage.TotalTokens = usage.PromptTokens + usage.CompletionTokens
	}
	return usage
}

// ExtractGenAIUsageJSON pulls usageMetadata from a buffered native
// (non-streaming) generateContent response.
func ExtractGenAIUsageJSON(body []byte) (Usage, bool) {
	var resp struct {
		UsageMetadata *usageMetadataRaw `json:"usageMetadata"`
	}
	if err := json.Unmarshal(body, &resp); err != nil || resp.UsageMetadata == nil {
		return Usage{}, false
	}
	return resp.UsageMetadata.toUsage(), true
}

// ExtractGenAIUsageSSE scans one native SSE data line for usageMetadata —
// the final chunk of a streamGenerateContent stream carries it.
func ExtractGenAIUsageSSE(data []byte) (Usage, bool) {
	var chunk struct {
		UsageMetadata *usageMetadataRaw `json:"usageMetadata"`
	}
	if err := json.Unmarshal(data, &chunk); err != nil || chunk.UsageMetadata == nil {
		return Usage{}, false
	}
	return chunk.UsageMetadata.toUsage(), true
}
