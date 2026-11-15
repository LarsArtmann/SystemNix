# Night-shift deploy marathon: crash-loop wave gens 1008–1011 + runner decoupling

**Session:** 2026-11-14 18:45 → 2026-11-15 09:35 (continuation of the 16-20/18-30 crash-loop arcs). Owner directive: "deploy! and fix bugs while I sleep… You are allowed to ignore PSI warnings… GET SHIT DONE." Outcome: **five forced deploys (gen-1008 → 1011) all anchored; all four battery legs PASS; the runner chgrp-walk decoupling landed and is live-verified; rows ticked + CHANGELOG recorded (db88f7a27).**

## a) The deploy chain (each forced DEPLOY_FORCE_PRESSURE=2, owner-exempt)

| Gen | Landed | Carried | Pre-flight catch |
| --- | --- | --- | --- |
| 1008 | 21:07 (75-min activation) | wave + runner fix + SC2129 + invoices/go-health floats | SC2129: the wave commit's OWN publish-gate emitter failed shellcheck — never build-proven before (first keep-going run caught it; `83b868d08`) |
| 1009 | ~23:20 | immich caps leg 1 (d8b7b4baa) | — |
| 1010 | 01:25 | setpriv peer-auth (a667d6bdd) | — |
| 1011 | 09:16 (88-min, the 07:48 log) | CAP_CHOWN+FOWNER (rode 740a9f3ec) | — |

## b) Battery verdicts (all PASS)

- **audiblesync**: ActiveState=active, :8481 bound, `/healthz` 200.
- **monitor365**: zero new `core.dmesg.966.*` post-deploy (baseline 15:01/15:43); agent active; SIGSYS grant holds.
- **immich converger** (gen-1011, the four-layer dig): `Result=success`, `INSERT 0 1`, `takeout-import.env` **0400 lars:users**, `takeout-import (nix-managed)` row in `api_key`. Layers cleared in order, each sandbox-proven (systemd-run with the unit's exact hardening) BEFORE its deploy: StateDirectory 226 → CAP_SETUID/SETGID vs `harden`'s empty bounding set → runuser's PAM session (`cannot open session` under ProtectSystem=strict) replaced by **setpriv peer-auth** → CAP_CHOWN/CAP_FOWNER for the chown-to-consumer + chmod-0400 handoff. CAP_SYS_RESOURCE (8e3b24a84, a parallel session's pam_limits leg) stays as inert spare under setpriv.
- **bank-sync**: PASS at the pin-doctrine float **8e170d05** (18740aed0 superseded the ad8a90c9 repin mid-deploy-day): one stable process since 21:08 (NRestarts=0), wise sync completing (1m22s), mesh seam publishing, zero exit-65. The readiness flapping is IN-PROCESS storm degradation (`storage probe failing` → `recovered`) with automatic recovery — not a restart loop; the earlier "never opens its port" verdict described only the 19:xx–21:05 window.

## c) The runner fix, live-verified (7447a2f8f)

The chgrp/chmod walks left the 3-min start chain for a timer-driven oneshot (own 30-min budget, stale-uid `find -quit` guard, parallel `wants` pull at every runner start). Live proof: the repair ran **6min18s outside the chain** under PSI 99 (22:01–22:08) and completed; the runner never waited; CI up. Same-day surgical unstick: sudo-kill the starved chgrp/chmod walks mid-flight — their `|| true` completes the ExecStartPre leg and the runner starts.

**The bigger discovery:** the storm-day stuck runner start job ALSO held the boot transaction open, so `systemd-analyze` refused → boot-metrics joined the still-open transaction at its timer fire and then **self-held it** (its own job extended the transaction while its script waited for the transaction to close) → `boot_phase_duration_seconds` absent → **every deploy deadlocked on the §10 phantom-metric gate**. Unblocked by letting the emitter's own 24-min retry budget exhaust (job exits → transaction closes → manual `systemctl start boot-metrics-emit` emits instantly). gen-1008's first refusal was exactly this.

## d) New traps recorded

1. **systemctl CLI decodes `\x` escapes in unit-name args** — `'forgejo-runner-evo\x2dx2.service'` (the memory-note form) resolves to the WRONG unit for `is-active`/`status`/`cat` (`No files found for forgejo-runner-evox2dx2.service`; `is-active` → inactive/not-found) while journalctl accepts the same string. **busctl with the dbus-escaped path (`…/forgejo_2drunner_2devo_5cx2dx2_2eservice`) is the ground truth.** This session briefly concluded the runner was "gone" from three mangled probes.
2. The auto-commit daemon + three parallel morning sessions raced every `git commit` (lost HEAD-locks ×7, one stale index.lock from an interrupted commit, my staged fix absorbed into a parallel session's docs commit 740a9f3ec — content verified before accepting).
3. Deploy wall-time under PSI 99 is 75–88 min/switch (post-crash-calm-gate waits dominate); five sequential forced switches never froze — the "twice-fatal" extreme-band warning did not reproduce with mostly-cached builds.

## e) Coordination ledger

Parallel band-80 session (see their 21:20 + 07:xx reports): monitored my deploys, root-caused immich legs alongside (their caps + pam_limits commits), re-armed/retired the deploy waiter (expired 02:00 unfired — single-deploy invariant held), pushed the 28+ commits (branch now up to date; push-stall-watch cleared). Overnight swarm: tq dispatches (CV session), audiblesync upstream combine, signoz shim work — all landed via daemon batches; my deploys carried their committed tree states (each reviewed before firing).

## f) Residue / follow-ups

- Baseline storm-era smoke fails (llama embeddings :8848, tq-agent-pool PSI-gated, Health-Hub 503, Kith CRM 303, borg-offsite tripwire, immich-server thumbnail spam under storm) — all matched previous-run baselines (advisory); none are wave regressions.
- `CapabilityBoundingSet` CAP_SYS_RESOURCE is an inert spare under setpriv — cleanup pass can drop it.
- The immich converger's deeper verify (authenticated request with the minted key) — next takeout-import run is the organic proof.
