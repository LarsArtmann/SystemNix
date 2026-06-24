# Session 73 — Hermes Emergency Fix + Full System Status

**Date:** 2026-05-21 07:53 CEST
**Hostname:** evo-x2 | **Uptime:** 3h | **Load:** 6.61, 8.28, 11.21
**Platform:** NixOS unstable (nixos-unstable) | **Kernel:** 6.x

---

## Executive Summary

Hermes AI Agent Gateway was **completely non-functional** due to two missing Python packages in the Nix sealed venv. Root cause: upstream `hermes-agent` deliberately excludes `discord.py` (messaging) and `anthropic` from the `[all]` extra, relying on runtime `pip install` which doesn't work in Nix-managed environments. Fix: pass `extraDependencyGroups = ["messaging" "anthropic"]` through the overlay chain. Build + deploy succeeded. Hermes now runs with Discord adapter and Anthropic provider. External GLM-5.1 rate limit (429) remains until 09:32 UTC.

---

## A) FULLY DONE ✅

### Hermes Discord + Anthropic Fix
- **Root cause:** `pyproject.toml` `[all]` extra excludes `messaging` (discord.py, telegram, slack) and `anthropic` — upstream expects lazy pip install at runtime
- **Fix:** Added `extraDependencyGroups = ["messaging" "anthropic"]` to hermes-agent override in `modules/nixos/services/hermes.nix:36`
- **New packages in sealed venv:** discord.py 2.7.1, anthropic 0.87.0, python-telegram-bot 22.6, slack-bolt 1.27.0, slack-sdk 3.40.1, qrcode 7.4.2, pynacl 1.5.0, brotlicffi 1.2.0.1, tornado 6.5.5, davey 0.1.4, docstring-parser 0.17.0, pypng
- **Verified:** No more "discord.py not installed" or "anthropic ImportError" in journal
- **Committed:** `dc9eaf87` (partial), full via `5328769f` (graphical.target move)

### Boot Performance (Session 71-72)
- `boot.tmp.useTmpfs = true` — 56% boot time reduction (2m13s → 58s)
- `unbound-anchor` fetch eliminated — saves ~4s per boot
- `hermes fixPermissionsScript` conditional — saves ~18s when perms already correct
- Hermes moved to `graphical.target` — doesn't block multi-user anymore

### Nix Versioning Anti-Pattern Elimination (Session 70)
- `self.rev`/`self.shortRev` eliminated across 29 repos
- All packages now use hardcoded semver
- Automated via update scripts

### Vendor Hash Cascade Fix (Session 68-69)
- Go dependency updates propagated through all consumers
- whisper-asr tmpfiles fix for voice-agents Docker

---

## B) PARTIALLY DONE 🔧

### Hermes Service
- **Fixed:** Discord adapter loads, Anthropic provider available
- **Still broken:** GLM-5.1 API rate limited (HTTP 429) — external, resets ~09:32 UTC
- **Known issue:** `firecrawl` lazy-install fails (no pip in Nix) — needs `firecrawl-py` added to `extraDependencyGroups` if web_search tool is needed
- **Known issue:** `origin` git remote not accessible from hermes sandbox — hermes trying to push to git but can't

### TODO_LIST.md
- P1 items (deploy + verify) from session 74 still unchecked — most are now done but not updated
- P2 code improvements partially done (dns-failover sops done, others not)

---

## C) NOT STARTED ⏳

### From TODO_LIST.md
- [ ] **Add per-threshold SigNoz channel routing** — critical→Discord, warning→log
- [ ] **Consolidate voice-agents Caddy vHost** into caddy.nix pattern
- [ ] **nix-colors integration** — wire to Home Manager, migrate 17+ hardcoded colors
- [ ] **Deploy Dozzle** — Docker container log tailing at `logs.home.lan`
- [ ] **Provision Pi 3** for DNS failover cluster
- [ ] **Wire Pi 3 as secondary DNS** in dns-failover.nix
- [ ] **Convert go-auto-upgrade `path:` inputs to SSH URLs**
- [ ] **Create shared flake-parts template** (mkGoPackage, checks, devshells)

### New Opportunities
- Add `firecrawl` to hermes `extraDependencyGroups` — web_search tool currently broken in Nix
- Add `edge-tts` to hermes `extraDependencyGroups` — TTS unavailable in Nix
- Add `fal` to hermes `extraDependencyGroups` — image generation unavailable
- Investigate hermes git remote access (SSH key / deploy key needed in sandbox)
- `file-and-image-renamer` disabled due to Go 1.26.3 requirement — needs upstream bump

---

## D) TOTALLY FUCKED UP 💀

### GLM-5.1 API Rate Limiting
- **Severity:** Critical — ALL hermes cron jobs failing
- **Details:** Both `open.bigmodel.cn` and `api.z.ai` endpoints returning HTTP 429
- **Error:** "Rate limit reached for requests" / "您的账户已达到速率限制"
- **Reset:** ~2026-05-21 09:32:50 UTC (07:32 CEST)
- **Impact:** `gatus-auto-responder`, `friendly-check-in`, `hermes-git-auto-commit`, `email-triage` all dead
- **Cascading effect:** Cron job failures trigger Discord send → interpreter shutdown crash → exit code 1 → systemd restart loop
- **Action needed:** Wait for rate limit reset, then monitor if it reoccurs. Consider rate limit backoff strategy or secondary API provider.

### Swap Pressure
- **9.2 GiB of 13 GiB swap used** — system is memory-starved
- **45 GiB of 62 GiB RAM used** — heavy load from AI workloads
- Multiple AI services (Ollama, ComfyUI, Hermes) competing for RAM

### Load Average
- **6.61 / 8.28 / 11.21** — system under significant load (this is an 8-core machine)
- Likely caused by AI workloads + hermes restart cycles + build processes

---

## E) WHAT WE SHOULD IMPROVE 📈

### Critical
1. **Hermes needs ALL lazy-deps pre-built in Nix** — the runtime pip install pattern is fundamentally incompatible with Nix. Need a comprehensive `extraDependencyGroups` list covering: `firecrawl`, `edge-tts`, `fal`, `exa`, `parallel-web`, `dingtalk`, `feishu`, `matrix`, `voice`, `bedrock` (everything hermes config enables)
2. **Hermes needs a secondary LLM provider** — single GLM-5.1 dependency creates SPOF for all cron jobs
3. **Rate limit backoff strategy** — hermes retries 3 times then crashes. Should gracefully degrade and wait
4. **Memory management** — 9.2GiB swap is crisis-level. Need to audit which AI services are running simultaneously

### Architecture
5. **Hermes git access** — sandbox can't reach `origin`. Needs SSH deploy key or git credential setup
6. **firecrawl integration** — add to Nix deps or find alternative web search that works without pip
7. **`file-and-image-renamer`** — blocked on Go 1.26.3. Bump or replace

### Code Quality
8. **Status report automation** — should be a justfile command, not manual
9. **TODO_LIST.md accuracy** — several items done but not checked off
10. **Flake inputs audit** — 47 inputs, some may be stale or unused

---

## F) TOP 25 THINGS TO DO NEXT

| # | Priority | Task | Impact | Effort |
|---|----------|------|--------|--------|
| 1 | P0 | Add `firecrawl` to hermes `extraDependencyGroups` — web_search broken | High | Low |
| 2 | P0 | Monitor GLM-5.1 rate limit reset at ~07:32 CEST, verify hermes cron jobs recover | High | None |
| 3 | P0 | Add `edge-tts` to hermes `extraDependencyGroups` — TTS broken in Nix | Medium | Low |
| 4 | P1 | Configure secondary LLM provider for hermes (OpenRouter/OpenAI) as GLM fallback | High | Medium |
| 5 | P1 | Audit memory usage — 9.2GiB swap is unsustainable. Identify hogs | High | Low |
| 6 | P1 | Deploy SigNoz channel routing (critical→Discord, warning→log) | Medium | Medium |
| 7 | P1 | Consolidate voice-agents Caddy vHost into caddy.nix pattern | Medium | Low |
| 8 | P1 | Provision Pi 3 for DNS failover cluster | High | High |
| 9 | P2 | Wire Pi 3 as secondary DNS in dns-failover.nix | High | Medium |
| 10 | P2 | Deploy Dozzle at `logs.home.lan` for Docker log tailing | Medium | Low |
| 11 | P2 | nix-colors integration — migrate 17+ hardcoded colors | Medium | High |
| 12 | P2 | Convert go-auto-upgrade `path:` inputs to SSH URLs | Low | Low |
| 13 | P2 | Create shared flake-parts template (mkGoPackage, checks, devshells) | Medium | High |
| 14 | P2 | Update TODO_LIST.md — mark completed items, add new hermes findings | Low | Low |
| 15 | P2 | Add hermes `extraDependencyGroups` pattern to AGENTS.md | Low | Low |
| 16 | P3 | Hermes git remote access — SSH deploy key for sandbox | Medium | Medium |
| 17 | P3 | Add `fal` to hermes `extraDependencyGroups` — image gen broken | Low | Low |
| 18 | P3 | Add `exa` to hermes `extraDependencyGroups` — web search alt backend | Low | Low |
| 18 | P3 | Investigate hermes `voice` extra (faster-whisper) for Nix compatibility | Low | Medium |
| 20 | P3 | `file-and-image-renamer` — bump Go or find alternative | Low | Medium |
| 21 | P3 | Flake inputs audit — identify stale/unused among 47 inputs | Low | Medium |
| 22 | P3 | Create `just status` command for automated status report generation | Low | Low |
| 23 | P4 | Add `dingtalk` + `feishu` to hermes `extraDependencyGroups` if needed | Low | Low |
| 24 | P4 | Hermes cron job crash resilience — prevent interpreter shutdown cascade | Medium | High |
| 25 | P4 | GC old Nix store paths — 7,479 eligible, 82% disk usage | Low | Low |

---

## G) TOP #1 QUESTION 🤔

**The hermes `extraDependencyGroups` approach adds packages to the sealed venv, but upstream's `pyproject.toml` has exact version pins that may conflict with packages already in the `[all]` group.** For example:
- `[all]` includes `aiohttp==3.13.3` via `homeassistant`/`sms`
- `[messaging]` pins `aiohttp==3.13.3` — OK for now
- But `[voice]` pins `numpy==2.4.3` which may conflict with other deps

**The question:** Should we create a comprehensive list of ALL hermes extras needed for the Nix deployment now (messaging, anthropic, firecrawl, edge-tts, fal, exa, voice, etc.) and test them all at once, or add them incrementally as issues surface? The incremental approach risks repeated rebuilds (each taking ~10min), but a big-bang approach risks version conflicts that are harder to diagnose.

My recommendation: **Add them all at once** — `["messaging" "anthropic" "firecrawl" "edge-tts" "fal" "exa"]` — and let uv2nix's dependency resolver handle version conflicts in one build. If it fails, we get all the errors at once.

---

## System Vital Signs

| Metric | Value | Status |
|--------|-------|--------|
| **Root disk** | 82% (90G free / 512G) | ⚠️ Needs attention |
| **Memory** | 45Gi/62Gi (72%) | ⚠️ Heavy |
| **Swap** | 9.2Gi/13Gi (71%) | 🔴 Crisis |
| **Load avg** | 6.61 / 8.28 / 11.21 | ⚠️ High (8 cores) |
| **Uptime** | 3h | ✅ Fresh boot |
| **Nix store paths** | ~7,500 | ✅ Recently GC'd |
| **Build test** | `just test-fast` passes | ✅ |
| **.nix files** | 112 files, 14,949 lines | — |
| **Service modules** | 36 | — |
| **Flake inputs** | 47 | — |
| **Commits (total)** | 2,527 | — |
| **Unpushed commits** | 4 | ⚠️ |
| **Users** | 20 sessions | — |

## Services Status

| Service | Status | Notes |
|---------|--------|-------|
| **Hermes** | 🟡 Running | Discord adapter ✅, Anthropic ✅, GLM-5.1 rate-limited 🔴 |
| **Caddy** | ✅ | Reverse proxy |
| **Forgejo** | ✅ | Git hosting |
| **Immich** | ✅ | Photo management |
| **Authelia** | ✅ | SSO/Auth |
| **Homepage** | ✅ | Dashboard |
| **SigNoz** | ✅ | Observability |
| **Twenty** | ✅ | CRM |
| **Voice Agents** | ✅ | Whisper-asr + Docker |
| **Ollama** | ✅ | Local LLM |
| **ComfyUI** | ❌ Disabled | Manual enable only |
| **Photomap** | ❌ Disabled | — |
| **Minecraft** | ❌ Disabled | Server mode off |
| **TaskChampion** | ✅ | Task management |
| **Monitor365** | ✅ | Hardware monitoring |
| **DNS Blocker** | ✅ | Unbound-based |
| **Dual WAN** | ✅ | Failover |
| **Gatus** | ✅ | Uptime monitoring |
| **Disk Monitor** | ✅ | NVMe health |
| **NVMe Health** | ✅ | SMART monitoring |

## Session Timeline

| Time | Event |
|------|-------|
| ~07:00 | User reports Hermes down |
| 07:01 | Diagnosed: missing discord.py + anthropic, GLM-5.1 rate limited |
| 07:02 | Identified `extraDependencyGroups` override path in upstream `hermes-agent.nix` |
| 07:03 | Added `extraDependencyGroups = ["messaging" "anthropic"]` to hermes overlay |
| 07:04 | `just test-fast` passes |
| 07:05 | Full build started (background) |
| ~07:20 | Build succeeded — 12 new Python packages built |
| 07:22 | `just switch` — activation successful |
| 07:24 | Verified: no discord.py/anthropic errors in journal |
| 07:47 | Prior session commit: hermes moved to graphical.target |
| 07:53 | Writing Session 73 status report |
