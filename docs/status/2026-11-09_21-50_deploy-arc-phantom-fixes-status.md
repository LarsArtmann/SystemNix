# 08:02 float failure — verification, two gen-993/994 deploys, three live fixes

**Filed:** 2026-11-09 ~21:50 CET · **Directive:** pasted 08:02 deploy failure
(`nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` → float proof
RED, deploy aborted) with "fix until everything works".
**Point-in-time:** session start HEAD `d440ac9e8`, tree clean, gen-992 running.

## a) What the pasted failure actually was (already repaired before this session)

The 08:02 blanket float (24 root inputs) and its RED proof were **already
resolved** by the 19:17 CV session: proof roots were the nested-nixpkgs
`patchelf-0.15.2` build (patch set `patchelf-fix-executable-header-load-overlap`
does not apply; offender input never pinned down) + `go-taskqueue`/`bank-sync`
vendorHash re-stales; the repair followed the gate doctrine (lock restored from
`59d178abb`, the registry-matching graph; gen-992 deployed + anchored;
CHANGELOG line 11 documents it; report §d.1/§g.2 flag the revert for owner ack).

Live-verified by THIS session before acting (never assert from docs alone):

- `flake.lock` root inputs == `flake/expected-locks.nix` byte-truth
  (`bank-sync fab93068`, `go-taskqueue 4d6250ac`, `cv da7f3cbc`,
  `hermes-agent 21ae0e12`; root `nixpkgs` → node `nixpkgs_7` = `f9a75f41`).
  Trap noted: `jq '.nodes.nixpkgs'` reads a NESTED node (root maps to
  `nixpkgs_7`) — the jq read that "disagreed" with the registry was my own
  node-resolution error, not drift.
- `float-register: no drift — registry matches flake.lock` (deploy #1's run).
- Anchor: `/run/current-system` == `system-992-link` target.
- The 24-input re-float stays OWNER-GATED (report §g.2 of the 19:17 session);
  this session deliberately did NOT re-run `nix flake update`.

The remaining real gap: code committed after gen-992 (monitoring wave
`fd1b208e9` + `0bb953d24`) was undeployed (eval drv `kcsazqcdg…` ≠ running
deriver `p85gcdknj…`) → two deploys executed below.

## b) Deploy #1 (gen-993) — blocked, fixed, landed

1. First run: vetoed by the pressure gate (exit 12). Second run forced
   `DEPLOY_FORCE_PRESSURE=1` on the gate's own crosscheck evidence: PSI 73%
   with disks idle (busy 0.6-1.0%, max device 0.4%), one kworker D-state,
   stalled cgroup = `app-niri-ghostty-6977.scope` — the root-caused 2026-10-14
   ghostty io_uring phantom class; the `=1`-sufficient ladder comment covers
   exactly this refusal class (extreme-band `=2` needs PSI≥80 AND disk≥80).
2. Pre-deploy battery §10 caught a REAL defect in `fd1b208e9`: the new
   "PapDashboard Ingest" gatus check used bare `pat(*…reachable 1*)` which
   matches the metric's own HELP comment (the HELP text literally contains
   "reachable 1 when…") — phantom green. **Fixed** (gatus-config.nix): all
   three conditions moved to the repo's line-anchored VALUE form
   (`pat(*\n<metric> <v>\n*)`, the storage_collector_health idiom); both §10
   lints re-run clean; `--section-10-only` gate 82 passed / 0 failed.
3. Deploy landed as **gen-993** but the activation hung ~60 min: stc's
   transaction includes `llama-embeddings` (Requires=) → `post-crash-calm-gate`
   refused the whole hour on phantom PSI (70+ REFUSE cycles at 59-76% PSI with
   idle disks), then hit its 60-min cap at 21:07:46, exited 1 (designed
   refusal; cold-reader fleet stays down this boot), OnFailure toast fired,
   stc completed, profile anchored. Post-deploy smoke rc=3: the 5 FAILs are
   the documented chronic baseline (forgejo-runner ordering cycle, Health Hub
   /readyz 503, offsite-borg tripwire, CPU + journal sanity) — none caused by
   this deploy; the "NEW vs baseline" flag is baseline drift on forgejo-runner.

## c) The ingest probe was ALSO broken — fixed and proven live (gen-994)

Symptom: `system_papdashboard_ingest_reachable 0` while papdashboard served
200s and `127.0.0.1:8088` accepted v4 connects. Root cause: the probe line
shipped by `fd1b208e9` calls bare `bash -c`, but `bash` is NOT in the
collector's wrapper PATH (writeShellApplication runtimeInputs: coreutils,
gnugrep, gawk, getent, systemd, curl, jq, procps, sqlite — no bash; the file's
own convention is absolute store paths, cf. `${pkgs.findutils}/bin/find`) →
`timeout 5 bash -c …` dies rc=127 silently → reachable structurally 0 since
first scrape. **Fixed** (system-health.nix): `${pkgs.bash}/bin/bash` absolute;
sandbox-validated (systemd-run with the unit's PrivateTmp/ProtectSystem=full/
NoNewPrivileges/CapabilityBoundingSet: `SANDBOX_CONNECT_OK`). Deploy #2
carried it (battery 140/0), first live run flipped the gauge:
`system_papdashboard_ingest_reachable 1` (21:32:38, stable since), and all
three gatus conditions MATCH the live node-exporter body (glob-replication
probe, `~/.cache/probe-ingest-check.sh`) — the endpoint is deterministically
green. The gatus API itself needs an auth token (401) — probe via the body,
not the API.

## d) Structural finding (two live instances tonight): phantom PSI starves the calm-gate

`post-crash-calm-gate` refuses on raw IO PSI (≥40 band) with NO device-truth
crosscheck. The deploy pressure gate GOT its per-device %util crosscheck for
exactly this class on 2026-10-13/14; the calm-gate did not. Consequence
observed twice: every deploy activation that (re)queues a gated llama unit
under the chronic ghostty phantom stalls ~60 min at the cap and ends with a
designed refusal + OnFailure toast — gen-993 (gate 20:07→21:07, 60 min) and
gen-994 (gate ~21:20→cap ~22:16) both paid it. Worse, because the refusal
marks llama-embeddings failed, EVERY later stc re-attempts the start and
re-waits while the phantom persists.

## e) Evidence

- Deploy logs: `~/.cache/deploy-run-20261109{,-force1,-force1b,-fix3}.log` +
  `/var/log/systemnix-deploys/` counterparts.
- Gate: `journalctl -u post-crash-calm-gate` (REFUSE cadence 15s; cap line
  21:07:46 "Consumed 3.024s CPU over 1h 3.220s wall clock"; "Triggering
  OnFailure= dependencies").
- Anchors: 992 `ccyd4rrn…`, 993 `2gcb1qvx…`, 994 `46c1jwaq…` (each
  `readlink /run/current-system` == newest `system-<N>-link` by number after
  the tree drained).
- Probe fix proof: textfile `system_health.prom` reachable 0→1 at 21:32:38;
  gatus condition replication MATCH ×3.

## f) Follow-ups

1. **calm-gate (+ psi-wait-gate) device-truth crosscheck** — port the deploy
   gate's per-device %util into the admit decision (PSI-high + idle disks →
   admit with phantom note). Harvested: TODO_LIST + docs/todo/stability.md.
2. `inboxclean-sync` OAuth re-consent expired (exit 1 at 20:17, OnFailure
   fired) — owner action per the inboxclean runbook; already WARN-visible.
3. gatus 401: the API needs a token — post-deploy smoke should never probe it
   unauthenticated (this session nearly false-negatived on it); if any check
   ever switches to the API, wire the token from sops.
4. Baseline drift: forgejo-runner flagged "NEW" vs a baseline that no longer
   matches reality (f.46 of the 19:17 report wants the baseline named).

## g) Harvest ledger

| Item | Where |
| --- | --- |
| calm-gate/psi-wait-gate device-truth crosscheck (§f.1) | TODO_LIST.md + docs/todo/stability.md `[ready]` |
| §f.2-§f.4 | recorded here; §f.2 is owner-action (inboxclean runbook owns it), §f.4 duplicates the 19:17 session's f.46 row — deliberately not double-rowed |

Not harvested (deliberately): the two fixes (phantom-green anchors, bash probe
path) are DONE in this session, not queue work.
