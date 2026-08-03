# Shell Latency Benchmark & nix-direnv Cold Path Fix

**Date:** 2026-08-03 03:23
**Session scope:** Benchmark fish/shell startup + prompt latency, root-cause the "feels slow" problem, fix the dominant bottleneck.

---

## What Was Done

### 1. Shell Startup Benchmarks (FULLY DONE)

Measured fish vs bash startup latency using `date +%s%N` wall-clock timing (no `hyperfine` available):

| Shell & mode                          | min    | avg    | max    |
| ------------------------------------- | ------ | ------ | ------ |
| `fish -c exit` (non-interactive)      | 35.9ms | 40.5ms | 58.0ms |
| `fish -i -c exit` (interactive)       | 62.1ms | 67.3ms | 73.6ms |
| `bash -c exit` (non-interactive)      | 1.8ms  | 2.3ms  | 3.4ms  |
| `bash -i -c exit` (interactive)       | 16.5ms | 21.4ms | 29.3ms |

**Fish is ~3x slower than bash** for interactive startup.

### 2. Fish Config Profiling (FULLY DONE)

Used fish 4.8.1's built-in `--profile` to identify where the ~28ms of config load time goes:

| ms     | What |
|--------|------|
| 6.8    | `carapace _carapace fish \| source` — completion generator |
| 2.8    | `fzf --fish \| source` — key bindings |
| 2.5    | `starship init fish \| source` — prompt |
| 1.8    | `direnv hook fish \| source` |
| ~4.5   | `psub` temp-file machinery (mktemp/rm/cat) from `starship init ... \| psub` |

**Total profiled config load: ~28.6ms.** The remaining ~40ms is fish's own binary startup.

### 3. Root Cause Discovery (FULLY DONE)

The user reported the shell "feels a lot slower than that" — which led to discovering the **per-prompt** overhead vs startup overhead distinction.

**The real bottleneck:** `use flake` in `.envrc` triggers direnv cold reloads after `flake.lock` changes.

Measured the three-step breakdown:

| Step | Time | What happens |
|------|------|-------------|
| `nix print-dev-env` | 3.0s | Evaluates the entire SystemNix flake (59 inputs, 257 transitive nodes, hundreds of modules) |
| `nix flake archive --json` | 0.3s | Enumerates all flake inputs (258 store paths) |
| **258 x `nix build --out-link`** | **6.4s** | nix-direnv spawns a **separate nix process per flake input** to create GC root symlinks |

**Total cold path: ~9.7s** (observed 7-21s depending on cache state and system load).

**Root cause classification:**

| Cost | Whose fault | Why |
|------|-------------|-----|
| 258 process spawns (6.4s) | **nix-direnv** | It GC-roots each input with a *separate process* instead of batching. Pure inefficiency. |
| nix eval (3.0s) | **Split** | Nix evaluator is single-threaded, but SystemNix's 59 inputs + hundreds of modules makes it 5-10x heavier than typical |

### 4. nix-direnv GC Root Override (FULLY DONE)

**Fix committed:** `f3661bff chore(envrc): speed up nix-direnv with symlink-based gcroot helper`

Added a 4-line override in `.envrc` that replaces the 258 individual `nix build --out-link` process spawns with instant `ln -sfn` calls for paths that already exist in `/nix/store/`:

```bash
_nix_add_gcroot() {
  local storepath=$1
  local symlink=$2
  if [[ $storepath == /nix/store/* ]]; then
    ln -sfn "$storepath" "$symlink"
  else
    _nix build --out-link "$symlink" "$storepath"
  fi
}
```

**Results:**

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Cold path (after flake.lock change) | **14.8s** | **2.9s** | **5.1x faster** |
| Warm path (cache hit) | ~48ms | **45ms** | Unchanged (already fast) |
| Per-command overhead (warm direnv x2 + starship) | ~102ms | ~102ms | Unchanged (not addressed this session) |

**Safety:** The devShell profile closure (134 store paths) already protects all transitive dependencies from GC. The per-input symlinks are defense-in-depth. Worst case after `nix-gc`: `nix flake archive` re-fetches a few source paths (seconds) on next reload.

---

## What Was Partially Done / Could Be Better

### a) FULLY DONE

- Fish startup benchmarked (fish vs bash, interactive vs non-interactive)
- Fish config profiled with built-in profiler (identified top 5 slowest items)
- Per-prompt latency measured (starship render, direnv overhead, full fish round-trip)
- Direnv cold vs warm path measured and root-caused
- nix-direnv's `_nix_add_gcroot` function identified as the 6.4s bottleneck
- Fix implemented, tested, and committed
- Correctness verified (devShell loads, tools available, profile symlink correct)

### b) PARTIALLY DONE

- **Per-command warm overhead NOT addressed:** Every command still pays ~102ms (2x direnv at ~48ms + starship at ~6ms). The double direnv hook (`fish_prompt` + `fish_preexec`) was identified but not fixed.
- **Fish startup items identified but not fixed:** Carapace (6.8ms), fzf (2.8ms), and starship (2.5ms) each regenerate on every startup. Caching was proposed but not implemented.

### c) NOT STARTED

- Carapace completion caching (would save ~6.8ms per fish startup)
- Starship init caching (would save ~2.5ms + ~4.5ms psub overhead per startup)
- fzf keybinding caching (would save ~2.8ms per startup)
- Double direnv hook investigation (could save ~48ms per command)
- AGENTS.md gotcha table entry for this optimization
- Home Manager documentation of the `.envrc` override pattern

### d) TOTALLY FUCKED UP

- **First `.envrc` override was wrong:** Replaced ALL `_nix_add_gcroot` calls (including the profile one) with `ln -sfn`. This broke the profile symlink — it pointed at a temp profile path instead of resolving to the store path. The cache kept invalidating on every run (warm path became 780ms instead of 48ms). Fixed by adding a guard: only `ln -sfn` for `/nix/store/*` paths, fall back to `_nix build` for everything else (the profile needs store-path resolution).

### e) WHAT WE SHOULD IMPROVE

1. **The remaining 2.9s cold path is nix eval** — the Nix evaluator walks all 59 inputs + hundreds of modules. Could be improved with a narrower devShell or `nix-fast-build`, but that's a Nix-level limitation, not fixable in `.envrc`.

2. **Per-command overhead (~102ms) is the next target** — the double direnv hook is the main contributor. Need to investigate whether the `fish_preexec` hook is redundant with the `fish_prompt` hook.

3. **Fish startup could drop from 67ms to ~50ms** by caching carapace/fzf/starship init scripts. The binary floor dominates the rest.

4. **AGENTS.md needs an entry** documenting the `.envrc` override pattern and why nix-direnv is slow on large flakes.

5. **The `.envrc` override is fragile** — it monkey-patches nix-direnv's internal function. If nix-direnv renames `_nix_add_gcroot` in a future version, the override silently stops working and the user gets no error, just slow startup again.

---

## f) Next Steps (Prioritized)

1. Add AGENTS.md gotcha entry for the nix-direnv GC root optimization
2. Investigate the double direnv hook (`fish_prompt` + `fish_preexec`) — is the preexec hook redundant?
3. Cache carapace completions (6.8ms per startup → ~0ms)
4. Cache starship init via file instead of psub (7ms per startup → ~0ms)
5. Cache fzf keybindings (2.8ms per startup → ~0ms)
6. Measure real-world per-command latency in an actual terminal (not just `fish -i -c`)
7. Consider `nix_direnv_manual_reload` as an option for making the 2.9s cold path opt-in
8. Investigate whether a narrower devShell (fewer inputs loaded) reduces the 2.9s nix eval time
9. Consider upstreaming the `_nix_add_gcroot` optimization to nix-direnv (batch `nix build --out-link` calls, or detect already-existing store paths)
10. Add a comment to `.envrc` documenting nix-direnv version dependency
11. Benchmark ghostty terminal startup time (adds to perceived latency)
12. Consider transient prompt mode for starship (reduces per-command render cost)
13. Investigate whether `fish --no-config` + manual sourcing is faster than default config loading
14. Measure the eval-cache SQLite contention (`eval-cache-v6/*.sqlite is busy` error observed during cold path)
15. Consider splitting the devShell into a "light" (core tools) and "full" (all tools) variant
16. Profile whether `nix profile wipe-history` adds overhead to the cold path
17. Document the SystemNix flake size (59 inputs, 257 transitive nodes, 258 store paths) in AGENTS.md
18. Consider whether the 450MB eval-cache directory needs cleanup
19. Investigate fish 4.x startup improvements (fish 4.8.1 may have known startup regression)
20. Benchmark with `nix output-monitor` or `nix --profile` to see if profile management adds overhead
21. Add a direnv benchmark script to `scripts/` for future regression testing
22. Consider `watch_file` granularity — are we watching files that change too often?
23. Investigate whether `nix flake archive` can be skipped on warm path
24. Test whether the fix works correctly after `nix-collect-garbage` (do the ln symlinks survive?)
25. Consider a systemd timer that pre-warms the direnv cache after flake.lock changes

---

## g) Questions

1. **Do you want me to also fix the per-command warm overhead (~102ms)?** The double direnv hook is the main contributor — I'd need to investigate whether the `fish_preexec` direnv hook is redundant and can be removed, or if it serves a purpose (e.g., catching env changes mid-command). This touches Home Manager config, not just `.envrc`.

2. **Should I cache carapace/starship/fzf init scripts?** This would drop fish startup from 67ms to ~50ms by pre-generating their init scripts to files instead of piping through `source` each time. But it adds complexity (cache invalidation when versions change) and the savings are modest (~17ms).

3. **Do you want this upstreamed to nix-direnv?** The `_nix_add_gcroot` optimization (detect already-existing store paths, use `ln -sfn` instead of `nix build --out-link`) would benefit ALL large flake users, not just SystemNix. I can open a PR with the batch approach.
