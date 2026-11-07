# Gateway Live: rpi3 Outage → Host + LAN Captured, SearXNG Regression — Deploy Night Close-Out

**Date:** 2026-11-07 06:25 CET · **Instance:** crush-deploy-completion-20261107
**Trigger:** owner's 22:49 deploy (`nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`) aborted RED; session tasked to complete it.
**HEAD at deploy:** c95aa4092 lineage → switch generation `n2kjvp2mpb` (system-985, anchored, verified).

## 0. Verdict

The deploy **is live and anchored** (`/run/current-system == system-985-link == n2kjvp2mpb…`, verified). It carries the full night's batch: crm pin 0ce5ecc (OIDC readiness PASS), quotaboard 579af78 (+6.85 MiB, health 200), dnsblockd 847d81e3 **with gateway mode ARMED** (§23: "household capture LIVE"), vm-top-metrics units, boot-evidence-scratch-gc units, cv-credentials-store, buildflow/docs-gates/meta/papdashboard/signoz float wave. Post-deploy battery: **163 PASS / 7 FAIL / 15 WARN / 1 STORM-SUSPECT**, exit 3 = one NEW regression (SearXNG, triaged below).

Five deploy attempts; four died on four DIFFERENT gates (float RED ×1, pre-vacuum ×1, doc-counts ×1, reaper race ×1) — each was a real, distinct defect, each fixed at root. Full arc in §c.

## a) NEW regression: SearXNG returns zero results — root cause rpi3 outage, NOT searxng

- Post-deploy §smoke: service 200 but `search?q=test` renders **0 result articles** (re-verified by hand at 06:1x — NOT stale smoke; engines warm, still empty).
- **Chain:** SearXNG engines resolve by name → `getent hosts duckduckgo.com` = **192.168.1.200 (the lie)** → splice returns bot-walled 202s → engines parse nothing.
- **Why the designed protection failed:** the sibling's host-resolver companion (`platforms/common/dns-resolver.nix`) puts rpi3 (.151) first in resolv.conf — **and rpi3 is DOWN** (`ping .151` = 100% loss; `dig @192.168.1.151` = host unreachable). glibc falls through to 127.0.0.1 (dnsblockd) → lie wins by race. The design contract ("keeps git@github.com working") is met ONLY while rpi3 answers.
- **github.com also lied** (192.168.1.200): SSH-by-name refuses (the ADR-0011 documented consequence); HTTPS works only via the .200 splice.

## b) The wider outage: rpi3 down → evo-x2 holds .53 → LAN-wide capture

- rpi3 (.151) died independently between the 23:28 gateway-wiring report (topology live-verified then) and ~01:0x tonight — NOT caused by the evo-x2 switch (different host).
- Keepalived failed .53 over to evo-x2 (ping .53 = 0.05 ms = local holder); dnsblockd binds `*:53` (wildcard, `ss`-verified) → **the whole LAN's by-name traffic now rides the gateway lie/splice**.
- Splice pass-through works (DDG fetch through .200 returned real DDG content shape), so LAN HTTPS by name is functional-but-captured; non-TLS by-name (SSH, games) refuses per ADR-0011.

## c) Deploy arc (five attempts, four distinct blockers)

1. **22:49 owner run — float RED** (this session's input): crm pin wave mid-flight by sibling; kith-crm vendored pre-regen docserver + missing MaxOpenConns; cqrs-lint/meta/papdashboard stale shims; quotaboard@0161f38 upstream vendor/go.mod contradiction. Sibling session fixed all four surfaces (proofs 22:51→23:07 GREEN, floats registered 23:41/23:56).
2. **00:43 attempt — exit 129 (SIGHUP) mid-activation**: whole process tree died between nh build and stc; NO half-activated state (current-system still old; gen-984 unchanged). Same-shaped retry via `setsid` detach (survives parent-signal races).
3. **01:15 attempt — §15 pre-vacuum gate REFUSED**: boot `6d2a69e4` (2026-11-06 05:58 → **cut 01:06:21**, no shutdown sequence, no in-journal panic, 19 s to next boot = too fast for the 90 s watchdogd era → wedge + manual-reset shape, owner confirmation pending) had open stability rows + 7.8 G/8 G vacuum clock. **Pulled via `scripts/boot-evidence-pull.sh -b 6d2a69e4`** → committed (daemon sweep 7410fd903 carried it) → gate PASS. NOTE: the box **rebooted at 01:06 tonight** — the evidence file documents the window; freeze-ledger decision left to the owner.
4. **04:19 attempt — doc-counts FAIL**: `vm-top-metrics.nix` (daemon-swept 02:28) made nixosModules 147→148 with no doc re-stamp. Re-stamped **both** surfaces (README history line + count; FEATURES row + header; 153 files/5 helpers verified by `find`, not `ls`-glob) → check GREEN.
5. **04:29 attempt — reaper race killed an otherwise-green battery**: `rm -rf ~/.cache/go-build` hit a live CV golangci-lint/go-build writer, exit 1 under `set -euo pipefail`. **Fixed at root** (30168ee8a): all three reap loops now WARN-and-continue on partial reap (HM still fails loudly later if genuinely blocked).
6. **04:43 attempt — SUCCESS**: pre-deploy 130/6/0; nh build instant (store warm); switch 04:55→06:00 (65-min storm-night grind, verified HEALTHY mid-flight via ListJobs tail: 5 heavy oneshots — llama-embeddings backlog, nsfw-classifier GPU load); deploy.sh post-switch orchestration (OIDC converges, provisioners, GC) then §post battery.

## d) Verification residue (queued, not silently dropped)

- rpi3 outage triage — needs owner/physical attention; LAN-wide capture persists until it returns (rows added).
- §23 sed-leg unprovenness MATERIALIZED exactly as the queued row predicted: the live battery printed "armed on ?" (empty extraction) — arm-state came from behavior probes, not the leg. Fixture-test row updated with the live confirmation.
- :53 bind question ANSWERED live: `*:53` wildcard — the `dig @192.168.1.200` drill leg is valid (row ticked).
- SearXNG: needs rpi3 revival OR an owner decision to allowlist engine domains (capture-authority doctrine stays intact either way) — row added.
- Host-protection design gap: rpi3-first resolver has no fallback when rpi3 is down — the gateway then captures the HOST too; needs a design row (9.9.9.9 third-nameserver is unreachable-of-reach — the lie answers first).
