# Architecture-Catalog Go-Live Prep — Continuation (2026-09-30 07:42 CEST)

Continuation of
`docs/status/2026-09-30_05-43_architecture-catalog-golive-prep-runaway-containment.md`
(user order: execute the report's §f do-now items, keep the deploy queued, keep
going until done). Session scope: everything agent-actionable from the 05-43
report's §f list 1-22 + 39-42.

## 0. TL;DR

All agent-actionable prep work is DONE and verified (§1): the two 05-43 fixes
are confirmed intact in git, four more surfaces were updated to match them
(hub README, SystemNix runbook-side WARN text, registry comment, AGENTS.md),
the §f harvest is complete (services.md go-live row + two pipeline.md guard
rows + CHANGELOG), and formatting/todo gates pass. The deploy remains QUEUED
behind a 2h15m parallel-session IO storm (watcher #1 gave up after 40 min of
40-73% io PSI; watcher #2 armed with 60-min patience — it fires
`nix run .#deploy` itself on a sustained drain, and deploy.sh re-gates at
switch time). Everything left is owner-gated (§3).

## 1. Executed this session (verify-first)

1. **Multi-agent git verification (05-43 §f.24/§7.4)**: the runner-PATH edit
   landed in daemon commit `0751be6a` (forgejo.nix + runbook, 9 insertions;
   the edit is alejandra multi-line — formatter already passed over it). Hub
   edits landed in `4a3f0a6`/`7d37b9c` (setup-forgejo.sh sync-token mint
   section verified byte-level: revoke-before-mint, 40-hex gate, umask 077,
   value never printed).
2. **Hub README owner-setup rewritten (§f.22)**: now documents the sync-token
   file (`/var/lib/forgejo/.eventcatalog-hub-setup/sync-token`), the
   runner-PATH deploy prerequisite BEFORE first dispatch, idempotent token
   rotation, and the SystemNix completion chain pointer. dprint-clean.
3. **Registry attrname-addressability note (§f.42)**: configuration.nix
   registry comment block now records the live-verified quirk (bare
   `nixpkgs#…` resolves; the system-registry attrnames
   `nixpkgs-nixos-unstable#…` do NOT address — CI/workflow code must use the
   bare form).
4. **Sync-script WARN text names the token file (05-43 §7.2 cosmetic)**:
   `architecture-catalog.nix` PLACEHOLDER-skip message now points at
   `/var/lib/forgejo/.eventcatalog-hub-setup/sync-token` — rides the SAME
   pending deploy at zero cost. Extracted-script-text `bash -n` verified
   (53 lines, per the raw-script-string rule).
5. **todofix2.py forensics closed (§f.39)**: journal has zero traces (output
   rode pipes to the dead session); the script file was destroyed by the
   tmp-cleaner before its full reordering intent could be recovered — verdict:
   abandoned scratch, nothing to redo (the live TODO structure passes
   check-todo-system.sh). Recurrence is owned by the new pipeline.md guard
   row. Side-finding: `/tmp/sweep.py` is a LIVE parallel session's
   docs-health annotator (left alone, correctly), and the banned fixed-tmp
   debris `niri.prom.tmp` (lars-owned, 27 days stale, from the 2026-09-05
   incident era) sat in the textfile dir — **trashed this session**; 7
   root-owned 0-byte mktemp leftovers from storm days remain (random-suffix
   names, harmless, root cleanup optional).
6. **Harvest complete (§f.50 obligation)**: `docs/todo/services.md` go-live
   row rewritten as the deterministic 0-5 owner sequence (step 0 = deploy the
   runner-PATH generation first) with the full post-live verify chain;
   `docs/todo/pipeline.md` +2 `[ready]` rows (/tmp one-shot guard with the
   todofix2 evidence; pressure-gate multi-sample busy window per §7.5);
   `CHANGELOG.md` [Unreleased] entry added; AGENTS.md catalog section
   updated (sync-token chain + the runner-unit-PATH-is-job-PATH contract).
   `check-todo-system.sh`: OK.
7. **Formatting gates**: `scripts/fmt-cached.sh` on configuration.nix
   (0 changed); hub `dprint check` rc=0.

## 2. Deploy status (the one open executable item)

- Attempt #1 (05:25) gate-blocked rc=12 (avg10 28% at entry).
- The storm is LIVE parallel-session workload, not a wedge: census shows
  10× golangci-lint + nix builds (+ intermittent VM tests); disks genuinely
  busy (Samsung 35%, QLC 23% in a 4s window) — NOT the D-state-phantom class
  (the 05:41 gate's "corpse-pile" guess was wrong, §7.5; the classifier
  improvement is the new pipeline.md row). DNS stayed healthy throughout
  (dnsblockd answered instantly; one transient Ds worker observed and
  resolved).
- Watcher #1 (inline background shell, 120s cadence): 20 iterations, avg10
  46→73→56%, never 3 consecutive <20/<25 — gave up 07:38. Watcher #2 armed
  (180s cadence, 60-min patience) fires `nix run .#deploy` itself on a
  sustained drain; deploy.sh re-runs the pressure gate at switch time, so a
  mid-fire relapse costs another rc=12, never a dirty switch.
- NOT forcing (`DEPLOY_FORCE_PRESSURE=1`): freeze-#5 doctrine — deploys
  queued under sustained storms, not raced through dips.
- Post-deploy verify (§f.2): `grep path= /etc/systemd/system/gitea-runner-evo\\x2dx2.service`
  must show nix/jq/python3; then the §f.3+ owner chain below.

## 3. Owner sequence (deterministic, runbook-mirrored)

1. `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh`
   (idempotent; mints CI + sync tokens; sync token lands root-only at
   `/var/lib/forgejo/.eventcatalog-hub-setup/sync-token`).
2. Watch the first CI run (`forgejo.home.lan/lars/eventcatalog-hub/actions`)
   to green + `dist` branch. Watch-list: nix-daemon reachability for the
   DynamicUser runner, `npm` in job env, job-token push (`PUSH_TOKEN`
   fallback documented).
3. `SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age
   -private-key) sops platforms/nixos/secrets/architecture-catalog.yaml` —
   paste `ARCHITECTURE_CATALOG_SYNC_TOKEN=<hex>` from
   `sudo cat /var/lib/forgejo/.eventcatalog-hub-setup/sync-token`.
4. Deploy (if the watcher didn't already land the runner-PATH generation)
   — sops rotation restarts the sync unit.
5. `sudo systemctl start architecture-catalog-sync`; verify: journal
   "serving generation", `current/index.html` + `build-stamp.json`,
   collector `dist_present 1`/`fresh 1`, three Gatus checks green,
   post-deploy §15 stops warning.

## 4. Deliberately not done

- **Hub push**: 2 unpushed commits (README fix + script fix). The go-live
  script runs from the LOCAL checkout, so push is not required for go-live;
  never-push-without-ask stands. Owner: push when convenient to keep the
  GitHub↔Forgejo mirror coherent.
- **Hub CHANGELOG**: no CHANGELOG convention exists in that repo — README +
  TODO_LIST carry it instead.
- **Parallel-session artifacts flagged, not touched**: daemon commit
  `45f1cb0b` carried a flake.lock hunk alongside my configuration.nix
  comment (other session's lock churn); a new status report
  (`…gonix-relock-caddy-outage-discovery-status.md`) landed from a parallel
  session mid-window. My "flake check green" claims cover only my files;
  the deploy's own eval is the arbiter.

## 5. 05-43 §f disposition map

Items 1-2 → blocked on deploy §2. Items 3-18 → owner §3. Items 19, 23,
29-38, 43-50 → untouched (post-go-live / owner / long-term, tracked in
services.md + hub TODO). Items 20-22, 24-27, 39, 42 → DONE this session
(§1). Items 40-41 → harvested as pipeline.md `[ready]` rows. Item 38 →
done for the lars-owned debris; root-owned leftovers noted (§1.5).
