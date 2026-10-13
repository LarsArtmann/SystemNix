---
title: "Eventcatalog Wave-1 battery + Gatus crash-loop incident + drift-gate landing"
summary: >-
  The 2026-10-12 evening session executed Wave 1 of the post-go-live Pareto
  plan: the full live-verification battery (go-live proven TRUE on every
  agent-checkable surface), discovery of a total Gatus outage (config-parse
  crash loop, fixed + eval-guarded), resolution of all five owner gates
  (sync-token rescue authorized and executed with byte-verification, ntfy
  chosen, drift-gate landed warn-only, curation deferred to the opt-out
  design, owner takes the PAT/branch-protection UI battery), and the
  sources-coverage drift-gate implemented + fixture-tested in the hub.
---

# Status: eventcatalog Wave-1 battery + Gatus incident + drift-gate (2026-10-12, ~21:00–22:00 CEST)

> **SUPERSEDED (§b only) by `docs/status/2026-10-13_13-01_eventcatalog-wave1-execution-gatus-incident-sync-rescue-drift-gate.md`** — its "deploy pending" states converged the same evening (serving generation 23:20, anchor healed); §a/§d stand.

Scope: `docs/planning/2026-10-12_18-20_eventcatalog-post-golive-pareto-execution-plan.md` Wave 1 (P02–P04), the P01 owner battery, P05/P08/P09/P25 verdicts, and the P07 drift-gate implementation the §g.2 answer unblocked.

## a) FULLY DONE

1. **Wave-1 battery executed, verdict table appended to the 11-43 go-live
   report** — vHost 200 + EventCatalog title (via 192.168.1.150:443, the
   chain Gatus checks); llms.txt 200 + 4 source domains + 10/10 sampled
   links resolve (host stale = frozen dist, see b.1); llms-full.txt 200;
   schemas.txt **does not exist** (runbook phantom, corrected — real
   surface is `schemas/` dir + llms-full.txt); freshness gauges
   dist_present 1 / fresh 1 / age 49907 s / scrape_errors 0; build-stamp
   = 03:26 UTC nightly with all 4 source revs; mesh content renders
   (orders-svc 6 pages, billing-svc 11 pages, real titles); 173
   index.html; zero cross-source ID collisions (order.* members disjoint
   demo/mesh — latent first-source-wins shadow risk recorded in the hub
   ROADMAP-adjacent notes).
2. **Gatus crash-loop incident found + fixed** (`c18a78d6`, deploy in
   flight at authoring): `\\x2d` in the System-Health Metrics alert
   description failed config parse → 400+ restarts, ALL monitoring dark
   since 18:11. Fix = text rewrite + the new `gatus-alert-text-audit`
   eval assertion (388 descriptions scanned, 0 bad; all 2268 system
   assertions pass).
3. **Owner gates resolved** (P01, batched once): sync-token rescue =
   agent (done, see 4); alert channel = ntfy (secret paste stays
   owner-side, hub TODO row updated); drift-gate = warn-only soak with
   inline `excluded` (landed, see 5); curation = defer to the opt-out
   `catalog.json` design (no sources.json additions); PATs +
   dist branch protection = owner will do both in the Forgejo UI (row
   stamped with the verify protocol).
4. **Sync-token rescue executed** (`04a71dae`): current token from the
   root-only file sops-pasted via a runtime-var script (value never on a
   command line), decrypted extract byte-compared against the token
   file. Rides the same switch as the Gatus fix.
5. **Drift-gate landed in the hub** (`f284822`):
   `scripts/check-sources-coverage.sh` + build.yml WARN step + inline
   `excluded: []` in sources.json. KEY FINDING: the plan's
   `who-uses … --format json` premise was FALSE (the subcommand rejects
   the flag — plain tree only); the gate parses the rendered `[direct]`
   lines. Warn-only on the 8 known drifters; `--strict` built in for the
   post-soak fail-red flip (dated TODO row in the hub); fixture-tested
   (WHO_USES_CMD harness: warn-only / exclusion matching incl.
   parenthesized display names / strict exit 1); shellcheck clean.
6. **Surface closures on both repos**: SystemNix TODO_LIST + services.md
   (f.1 lint.export = CONSUMED via lint-sources.sh; f.3 mirror cadence =
   2 h `mirror.DEFAULT_INTERVAL`, worst case ≈27 h < 36 h budget; the
   two "bank-sync build phase dies" rows closed as stale survivors —
   runs 59–70 all green, run 70 all four sources FRESH; new rows: the
   sync-token rescue + the VM-test queue one-liner gap). Hub TODO +
   CHANGELOG updated (sync-token resolution, ntfy decision, soak row).
   Runbook stamps: cron TZ (03:23 UTC = 05:23 CEST, 3 spots), freshness
   arithmetic, AI-surface correction, architecture-gate claim corrected
   (NO source repo wires the gate yet — P25 audit; hub-side ready).
   CHANGELOG row (SystemNix) for the Gatus guard + battery.

## b) PARTIALLY DONE

1. **Serving is frozen until the switch lands** — the deploy was
   pressure-gated twice (parallel pbx-aarch64 build, then a §11
   tree-mutation race); watcher v2 re-runs `nix run .#deploy` when
   io-PSI < 20. Post-switch verification owed: gatus.service stable,
   sync unit converges on the sops restartUnits, stamp advances past
   2026-10-12T03:26Z, `current` advances. Freshness red was projected
   for 2026-10-13 ~17:26 CEST if the token never landed — the paste
   removes that deadline once live.
2. **Hub commits unpushed** (agent sessions never push): f284822 +
   4138ddf + ff358e3-era — the daemon pusher or owner carries them; CI
   picks the gate up on the first run after the mirror syncs.

## c) NOT STARTED (deliberately)

- Wave 2+ implementation items (P10 Go pin, P11 provenance footer, P12
  protection is owner-UI-in-flight, P13 needs the ntfy secret, P15 VM
  test, P16 SigNoz tile, P19 robustness batch, P17 exporter wave, P22
  webhook sync, P23 catalog.json design) — the plan gates them behind
  this verification wave + their own dependencies; rows/decisions are
  stamped, dispatch continues per the plan.

## d) TOTALLY FUCKED UP

1. **The §g.2 drift-gate design carried a fabricated flag.** Two
   sessions (deep-dive + plan authoring) spec'd `who-uses --format json`
   and nobody ran it until implementation time. The owner answered a
   governance question about a tool interface that did not exist. The
   repo's premise-check rule (spot-verify config claims at queueing
   time) exists precisely for this; it was applied to configs, not to
   command-line contract claims. Caught only by running the command.
2. **First sops verification script had a broken comparator** (awk
   field-split vs quoted YAML values) and reported a mismatch after a
   SUCCESSFUL set — a false alarm I then chased through a typed-sudo
   guard rejection before rewriting with `sops --extract`. The set was
   right; my check was wrong; evidence discipline held (byte-compare
   before any "verified" claim) but cost three cycles.
3. **The token paste verified the WRONG ENTITY — three deploys of
   self-inflicted churn.** I followed the runbook's env-file wording,
   created a NEW uppercase yaml key (`ARCHITECTURE_CATALOG_SYNC_TOKEN`)
   instead of updating the existing lowercase one
   (`architecture_catalog_sync_token`) that the module actually reads,
   and stored the bare token instead of the whole env line. My
   "byte-verified OK" checks compared the key I CREATED against the
   forgejo file — exactly the "assert WHICH entity served it" failure
   the repo rules warn about, one level down: assert WHICH KEY the
   renderer reads. The live render kept serving the old token through
   two deploys; the digest triad (tree yaml / forgejo file / rendered
   file) finally exposed it. The runbook step-4 wording is now fixed
   and the yaml carries only the correct key/shape.

## e) WHAT WE SHOULD IMPROVE

1. **Command-contract premises need a live run at design time** — extend
   the premise-check rule beyond config surfaces: any tool invocation
   written into a plan/owner question gets executed once (or marked
   UNVERIFIED in the text) before the plan ships.
2. **The daemon-sweep raced three commits today** (SystemNix ×2, hub ×1);
   each needed a show-stat + amend-forward. The amend-retry after a
   ref-move needs `git commit --amend` re-pinned to the NEW head —
   consider a `git amend-mine` helper that re-verifies exclusivity
   automatically.

## Harvest ledger

- Sync-token rescue row: HARVESTED at discovery (TODO_LIST + services.md,
  owner-gated).
- VM-test queue one-liner: added (closes the 16-00 Harvest Ledger's
  flagged queue/library drift).
- PAT row: owner-committed stamp + verify protocol appended (no new row).
- Drift-gate soak flip: hub TODO_LIST dated row (2026-10-19 earliest).
- P25 finding (gate unwired upstream): runbook correction only — the
  adoption campaign is hub- owned (blocked on the source-repo CI
  ownership answer, hub §g.3 — still open, not part of today's battery).
