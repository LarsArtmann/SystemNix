# Crush & Ollama Local Model Integration

**Date:** 2026-03-18 01:05

## Objective

Enable the Crush CLI AI assistant to seamlessly use local GLM-4.7-Flash quantisations running on Ollama.

## Implementation Details

Crush supports `openai-compat` providers, which perfectly matches Ollama's `v1` API compatibility layer. The configuration was added directly to `~/.local/share/crush/crush.json` instead of relying on Catwalk's remote `providers.json`.

### Crush Configuration Snippet

To register Ollama models, the following configuration was appended to the `providers` object in `~/.local/share/crush/crush.json`:

```json
"ollama": {
  "api_key": "ollama",
  "base_url": "http://127.0.0.1:11434/v1",
  "type": "openai-compat",
  "models": [
    {
      "id": "glm-4.7-flash:latest",
      "name": "GLM 4.7 Flash (Q4_K_M)",
      "context_window": 198000,
      "default_max_tokens": 8192
    },
    {
      "id": "glm-4.7-flash:q8_0",
      "name": "GLM 4.7 Flash (Q8_0)",
      "context_window": 198000,
      "default_max_tokens": 8192
    },
    {
      "id": "glm-4.7-flash:bf16",
      "name": "GLM 4.7 Flash (BF16)",
      "context_window": 198000,
      "default_max_tokens": 8192
    }
  ]
}
```

_Note: Crush expects `base_url` (not `api_endpoint` or `endpoint`) in the JSON schema for custom API URLs._

## Available Models in Crush

You can now verify the local models are available by running `crush models | grep ollama`:

- `ollama/glm-4.7-flash:latest` (Q4_K_M quantisation, 19GB)
- `ollama/glm-4.7-flash:q8_0` (Q8_0 quantisation, 32GB)
- `ollama/glm-4.7-flash:bf16` (BF16 unquantised, 60GB)

## Usage Examples

Run Crush from the command line using the `-m` flag to specify the local model:

```bash
# General query using the default (smallest/fastest) model
crush run -m "ollama/glm-4.7-flash:latest" "Explain the concept of Nix flakes"

# Read a file and use the 8-bit model
crush run -m "ollama/glm-4.7-flash:q8_0" "Refactor this code to be more idiomatic" < main.go
```

## Recommendations & Performance

**Recommendation:** Stick to `ollama/glm-4.7-flash:latest` (the Q4_K_M quantisation) for daily interactive use.

**Reasoning:**

1. **Memory constraints:** Your system has 128GB of RAM, but it's unified memory. Approximately 64GB is reserved for the GPU/NPU, leaving ~62GB visible to the OS.
2. **OOM Risks:** The BF16 model is 60GB on its own. Loading it leaves almost zero headroom for the OS, KV cache, or Crush itself, leading to swapping or Out-Of-Memory (OOM) crashes.
3. **Speed:** During testing, the `latest` tag (Q4_K_M) was successfully queried and returned accurate results, while larger models will be significantly slower due to memory pressure and memory bandwidth limits.
