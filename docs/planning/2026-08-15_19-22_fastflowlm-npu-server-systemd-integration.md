# FastFlowLM NPU LLM Server — SystemNix Integration Plan

**Status: EXECUTED 2026-08-15/17 — shipped as `541a6a1a` + `25790607`** (module `modules/nixos/services/fastflowlm.nix`, ports 52625/52626 in `lib/ports.nix`, socket activation via systemd-socket-proxyd). Verdicts per section below were rendered by the 2026-08-17 docs-health pass against the shipped code. Design agreed 2026-08-15.

Reference: `~/projects/anime-comic-pipeline/docs/npu-fastflowlm-llm-server.md` (manual install, measured numbers)
Target module: `modules/nixos/services/fastflowlm.nix`

---

## 1. Problem

FastFlowLM v1.0.1 (AMD ROCm org) serves Qwen3.6-35B-A3B (~3B active) from the
XDNA2 NPU of evo-x2. It currently runs as a hand-started process:

- Patchelf'd portable tarball in `~/.local/share/fastflowlm/` with hardcoded
  nix store rpaths — a `nix store gc` silently breaks it
- No restart-on-crash, dies with the shell, invisible to monitoring
- Model (13.6 GB) stays resident in RAM indefinitely once loaded

The goal: always-*available* (not always-*loaded*) local LLM on the NPU —
socket-activated cold load, idle unload after 1 h, monitored, declarative.

## 2. Verified constraints (live binary, v1.0.1 `--help`)

| Constraint | Consequence |
| --- | --- |
| No native idle-unload / keep-alive flag | TTL must be implemented at the systemd layer |
| No `sd_notify` (not Type=notify capable) | No watchdog; liveness via port/HTTP only |
| No systemd socket-fd support | Socket activation needs a proxy hop |
| Server logs every `TCP connection established` line to stdout | Idle detection is journal-greppable (monitor365-watchdog pattern) |
| `flm` wrapper needs a system bash | Wrapper must use a nix bash, not `/run/current-system/sw/bin/bash` |
| One LLM at a time; server swaps models on request naming them | Bind the module to ONE model; requests naming another model trigger a cold swap (acceptable) |
| `/dev/accel/accel0` is `root:video 0660` | Service user needs `video` supplementary group |
| memlock unlimited required for NPU | `LimitMEMLOCK = infinity` in unit + existing pam limits already set by `ai-stack` |

## 3. Measured baseline (2026-08-15, from anime-comic-pipeline doc)

| Resource | Idle | Generating (14 t/s) |
| --- | --- | --- |
| RSS | 24.9 GB (23.4 GB shared/mmap) | ~25.7 GB |
| CPU | 0.0% | ~19% of one core (0.6% of 32) |
| iGPU | untouched | untouched |
| RAM after start | 48/93 GB | — |

Shmem is swappable to zram under pressure → the cost model is **RAM capacity,
with graceful degradation (slower t/s) instead of OOM**. The anime-pipeline RAM
watchdog threshold (81 GB) has huge headroom with the model resident.

## 4. Architecture

```
client → 127.0.0.1:52625  fastflowlm.socket          ← stable public port (unchanged)
           └─ fastflowlm-proxy.service (socket-activated, systemd-socket-proxyd)
                └─ proxies to 127.0.0.1:52626
                   └─ fastflowlm.service (flm-real serve)  ← model resident here
                        └─ /dev/accel0 (NPU), /data/ai/models/fastflowlm (mmap)
```

- **Public port stays 52625** — zero client-side churn (anime-pipeline,
  Crush `openai-compat` provider, curl scripts).
- **Socket activation** (`fastflowlm.socket` → proxy): zero processes, zero
  RAM, zero NPU until first connection.
- **Backend** `fastflowlm.service` binds `127.0.0.1:52626`; the proxy unit
  ExecStart **waits for the backend port** (curl `--retry`, up to 3 min)
  before exec'ing `systemd-socket-proxyd` — otherwise proxyd forwards into a
  refused port mid-cold-load (13.6 GB read, ~1–3 min first token after idle).
- **Idle TTL** `fastflowlm-idle.service` (timer, every 5 min): stop proxy +
  backend when

  ```
  systemctl is-active --quiet fastflowlm.service
  && active-for ≥ 10 min            # don't kill a cold load in progress
  && journalctl -u fastflowlm --since "-1h" --grep "TCP connection established" | empty
  ```

  Every request flows through the proxy to the backend, so the backend
  journal is the single source of truth for "in use". Gatus must NOT probe
  :52625 — each probe is a TCP connection = permanent keepalive.

## 5. Components

### 5.1 Package — `pkgs/fastflowlm` (or overlay)

- `fetchurl` the v1.0.1 release tarball from
  `https://github.com/ROCm/FastFlowLM/releases` (pin by version + hash)
- `autoPatchelfHook`: interpreter + rpath become real store references →
  survives GC; kills the fragile manual patchelf. Needed libs (from the
  manual install): glibc, gcc libstdc++, curl, util-linux libuuid
- Wrapper script `flm`: sets `FLM_MODEL_PATH`, `XILINX_XRT=$out`, invokes
  `flm` bash entry with a **nix** bash (not `/run/current-system/sw/bin/bash`)
- bwrap/steam-run abandoned upstream of this plan (ENOSPC on this machine) —
  do not revisit

### 5.2 Module — `modules/nixos/services/fastflowlm.nix`

Options (`services.fastflowlm.*`):

| Option | Default | Notes |
| --- | --- | --- |
| `enable` | `false` | |
| `model` | `"qwen3.6-moe:35b-a3b"` | single bound model |
| `keepAlive` | `"1h"` | idle TTL window |
| `loadAsr` | `false` | `--asr 1` (whisper-v3) |
| `loadEmbed` | `false` | `--embed 1` (embeddinggemma) |
| `pmode` | `"performance"` | powersaver/balanced/performance/turbo |
| `host` | `"127.0.0.1"` | backend bind |
| `port` | `ports.fastflowlm` (52625) | public socket port |
| `backendPort` | `ports.fastflowlm-backend` (52626) | internal |

Service wiring:

- `systemd.services.fastflowlm`:
  - `User = primaryUser`, `SupplementaryGroups = [ "video" ]`
    (`/dev/accel0` is `root:video 0660`; lars is already in video)
  - `LimitMEMLOCK = "infinity"` (NPU requirement)
  - `after`/`wants`: `data.mount` (model mmap'd from `/data/ai/models/fastflowlm`)
  - `ExecStartPre`: gate on `/dev/accel0` existence + model dir non-empty
    (fail loudly, not crash-loop, on missing prerequisites)
  - `MemoryHigh = "26G"` / `MemoryMax = "32G"` — High nudges reclaim before
    the hard bound; shmem must reclaim (swap), not die
  - `harden {}` (with `ProtectHome = false` — model lives under `/data`,
    but the FLM_HOME state dir may touch `$HOME`; verify at build), plus
    `ioTier.background` (13.6 GB cold read must not starve boot/SSHD on QLC
    NAND)
  - `startLimitBurst = 5; startLimitIntervalSec = 300;` (top-level, NOT
    serviceConfig — systemd 261 silently ignores them in [Service])
  - `TimeoutStartSec = "3min"` (cold load exceeds the global 3-min default
    marginally with ASR/embed enabled — measure, keep explicit)
- `systemd.sockets.fastflowlm`: `ListenStream = 127.0.0.1:52625`,
  `Accept = false`, socket-activates the proxy
- `systemd.services.fastflowlm-proxy`:
  `ExecStart = wait-for-backend script, then systemd-socket-proxyd 127.0.0.1:52626`;
  `Requires = fastflowlm.service` (starting proxy pulls up the backend);
  `PartOf = fastflowlm.service` (idle stop tears both down)
- `systemd.timers.fastflowlm-idle` + `fastflowlm-idle.service` (oneshot):
  the TTL check from §4, using `journalctl --grep` + `-n` cap (never
  `journalctl | grep` — the IO trap)

### 5.3 Ports — `lib/ports.nix`

```nix
fastflowlm = 52625;
fastflowlm-backend = 52626;
```

### 5.4 Model paths — `ai-models.nix`

Add `/data/ai/models/fastflowlm` to the declarative `paths` family +
tmpfiles rule (0775, cfg.user/group). Model downloads stay imperative
(`flm pull`) — 13.6 GB binaries do not belong in the store.

### 5.5 Monitoring — no keepalive-defeating probes

- **No Gatus HTTP check on :52625** (see §4)
- `system-health` collector gains a fastflowlm section (niri-health-metrics
  pattern):
  - `fastflowlm_failed = 1` if unit in failed state (crash) — Gatus alerts
  - `fastflowlm_crash_loop = 1` if ≥3 restarts in 10 min — Gatus alerts
  - idle-stopped (socket waiting) = **healthy**, emits 0s
- Gatus checks match `fastflowlm_failed 0` / `fastflowlm_crash_loop 0`
  (liveness + health conditions, house pattern)

### 5.6 Homepage / DMS

Optional: Homepage tile guarded by `lib.optionalString` — point it at
`/v1/models` **is forbidden** (keepalive probe). If a tile is wanted, gate
it on the health-metrics endpoint instead, or skip the tile entirely.

## 6. Validation plan

1. `nix flake check --no-build` — module auto-discovery, ports uniqueness
2. Eval assertions: port collision, model dir present check wired
3. Deploy → `systemctl stop fastflowlm` (simulate idle), `curl
   127.0.0.1:52625/v1/models` → socket activation fires, first request
   succeeds after cold load (expect 1–3 min TTFT)
4. Confirm idle unload: no traffic for 1 h → both units inactive, RSS
   drops ~25 GB, zram frees
5. Crash test: `kill -9` flm-real → restart policy fires, health metrics
   alert path works
6. GC test: `nix store gc` → wrapper still functional (the original
   fragility)
7. Concurrency: anime-pipeline + ollama (iGPU) + fastflowlm (NPU)
   simultaneously — verify no NPU/iGPU contention regression

## 7. Optional extensions (not in scope)

- `warmupCalendar` (e.g. `OnCalendar = 09:00`) — pre-load before work hours
  if the cold start annoys
- `--asr`/`--embed` slots for whisper-v3 / embeddinggemma via module flags
  (options exist; defaults off)
- Crush provider config is already documented in the anime-comic-pipeline
  doc — unchanged, `http://127.0.0.1:52625/v1` keeps working transparently

## 8. Follow-ups after implementation

- Update `~/projects/anime-comic-pipeline/docs/npu-fastflowlm-llm-server.md`
  to reference the declarative service (keep measured numbers)
- Delete the manual `~/.local/bin/flm` wrapper + patchelf'd tree after the
  package proves stable
- AGENTS.md: add fastflowlm to the ioTier background table + module list
- TODO_LIST: reclaim the old `/rust-cache` partition (pre-existing, unrelated)
