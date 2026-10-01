# Architecture-Catalog Go-Live Prep — Continuation 2 + Overnight Outcome (2026-10-01 02:11 CEST)

Continuation of `docs/status/2026-09-30_07-42_architecture-catalog-golive-prep-continuation.md`
(itself continuing the 05-43 report). Session window: Sep 30 06:25 → 08:57
(active), then the session sat idle ~16h, resumed Oct 1 02:08 to find the
world had moved.

## 0. TL;DR + WHAT I FORGOT

**The runner-PATH fix is LIVE** (system-810, deployed Sep 30 15:48 by another
actor — user or a parallel session; my watcher #3 had given up ~10:39).
Verified in the deployed unit: `Environment="PATH=…"` now carries
nix-2.34.8 + jq-1.8.2 + python3-3.14.7 (NOTE: the nixpkgs module renders the
`path` option as an `Environment="PATH=…"` directive, NOT a `path=` unit
directive — my exact-match grep for `^path=` false-negatived before the loose
grep found it). The new sync-script WARN text is also live (journal shows the
sync-token path message). The go-live chain beyond that is still
PLACEHOLDER-inert by design (owner chain not run; hub unchanged, 2 unpushed).

**What I forgot — honest list:**
1. **Self-firing automation verdict persistence (the big one).** Watcher #3
   was armed to self-fire the deploy + verify the PATH, logging ONLY to its
   background-shell buffer. The session gap killed the buffer: whether it
   fired, what it saw, and its PATH verdict are UNKNOWABLE (the 15:48 deploy
   was NOT it — it was dead by then). Harvested as a pipeline.md row.
2. **Explicit closure of the 05-43 report's §g questions** in my final
   message (deploy authority / hub push / todofix2 ownership) — the user's
   new instruction answered #2 implicitly, forensics killed #3, but I never
   said so in one place. Done here: §g.
3. **§f.45 (system-health monitored-unit row rendered) was deferred without
   an explicit "deferred because" annotation** in the 07-42 report — it sat
   inside a bulk "untouched" range. It needs an eval or root probe; deferred
   again here, now explicitly (post-deploy item, §f.26 below).
4. **Daemon-commit exclusivity sweep was partial**: I `git show --stat`-ed
   the 4 commits that touched MY files, but never built the full
   batch-files→commits map the parallel session's own §d row asks for.
5. **The `45f1cb0b` flake.lock churn was flagged but not identified** (which
   inputs moved) — deliberate (no-unrelated-research), but it should have
   been LISTED as a conscious skip. The parallel session's own
   gonix-relock report presumably covers it.

## a) FULLY DONE

1. **Multi-agent git verification (05-43 §f.24/§7.4)**: runner-PATH edit
   confirmed in `0751be6a` (formatter-passed, alejandra multi-line); hub
   setup-script sync-token section byte-verified (revoke-before-mint, 40-hex
   gate, umask 077, value never printed).
2. **Hub README owner-setup rewritten** (§f.22): sync-token file, runner-PATH
   prerequisite, idempotent rotation, SystemNix completion-chain pointer.
   dprint-clean.
3. **Registry attrname-addressability note** (§f.42) in configuration.nix
   (bare `nixpkgs#…` resolves; `nixpkgs-nixos-unstable#…` does not).
4. **Sync-script WARN text names the token file** (05-43 §7.2) — extracted
   text `bash -n` verified (53 lines); **confirmed LIVE in the journal**
   post-810 (the skip line carries the sync-token path).
5. **todofix2.py forensics closed** (§f.39): zero journal traces (output
   piped to the dead session); script destroyed by the tmp-cleaner before
   full intent recovery — verdict: abandoned scratch (live TODO structure
   passes the checker). Recurrence owned by the pipeline.md guard row.
6. **Textfile debris sweep** (§f.38): trashed the banned fixed-tmp
   `niri.prom.tmp` (lars-owned, 27 days stale); 7 root-owned 0-byte mktemp
   leftovers remain → harvested as a [ready] row.
7. **Harvest complete per doctrine**: services.md go-live row rewritten
   (now reflecting the DONE prerequisite), pipeline.md +2 rows on Sep 30
   (/tmp one-shot guard, pressure-gate multi-sample classifier) and +4 rows
   on Oct 1 (textfile retention, automation-verdict persistence,
   degenerate-artifact guard, unattended-deploy policy [decision]);
   `check-todo-system.sh` OK both times.
8. **CHANGELOG entry** (SystemNix [Unreleased]); hub gets none (no
   CHANGELOG convention in that repo — decision recorded).
9. **AGENTS.md catalog section updated**: sync-token go-live chain +
   the runner-unit-PATH-is-job-PATH contract (landed `0751be6a` noted).
10. **Formatting gates**: fmt-cached on configuration.nix (0 changed); hub
    `dprint check` rc=0.
11. **Overnight-state reconciliation (this resume)**: profile system-810
    (Sep 30 15:48) identified; runner unit PATH verified live; sync journal
    + collector textfile read (still PLACEHOLDER-inert, honest zeros);
    hub repo unchanged (HEAD `5ec04cd`, 2 unpushed, clean tree).
12. **Deploy-watch campaign (Sep 30 morning)**: three inline watchers, ~2h
    of 2-5-min PSI sampling against a 3.5h storm (avg10 12-77%); none
    fired (correctly — the lone qualifying dip at 08:08 lasted <3 min and
    was followed by a 47% spike: the exact freeze-#5 racing-dips trap the
    3-consecutive-sample trigger refuses). No `DEPLOY_FORCE_PRESSURE=1`
    without owner order.

## b) PARTIALLY DONE

1. **The deploy itself**: the fix IS deployed (system-810), but NOT by my
   automation — watcher #3 died unfired/unknowable with the session gap.
   Outcome good, mechanism unproven; the verdict-persistence gap (§0.1) is
   the lesson.
2. **Daemon-commit exclusivity verification**: 4 commits spot-checked
   (0751be6a, 45f1cb0b, 784b4926, 651cb816 — my content present, expected
   neighbors), but no exhaustive batch map for the full Sep-30-morning
   commit series.
3. **Post-live verification chain** (§f.11-18 of the 05-43 report): the
   prerequisite leg (runner PATH) is now verifiable-DONE; the dist/serving
   legs await the owner chain.
4. **Three mid-air collisions with parallel sessions** (configuration.nix,
   AGENTS.md, services.md): all handled correctly (tool refused → re-read →
   re-apply → verify), but each cost a round trip — see §e.4.

## c) NOT STARTED (owner/root/auth-gated — sandbox bans `sudo`/`systemctl`,
Forgejo 401s anonymous probes)

1. `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh` (mirror,
   Actions, both PATs, sync-token file, mirror-sync refresh, first dispatch).
2. Watching the first CI run (browser/OIDC-gated) + triage against the
   watch-list (nix-daemon reachability for the DynamicUser runner, npm in
   job env, job-token push with PUSH_TOKEN fallback).
3. sops-paste of `ARCHITECTURE_CATALOG_SYNC_TOKEN` (needs the host age key).
4. The post-token deploy + `systemctl start architecture-catalog-sync`.
5. Hub repo push (2 unpushed commits — never-push-without-ask).
6. Post-go-live items: scratch cleanup (`eventcatalog-t0`), hub TODO [x],
   AGENTS.md header to LIVE, runbook LIVE banner, §f.29-38/43-50 items.

## d) TOTALLY FUCKED UP

1. **Empty-file `bash -n` false green**: my first extraction of the sync
   script text failed (awk pattern mismatch → 0 lines) and the pipeline
   still printed `SYNTAX OK (0 lines)` — a verification that CANNOT fail.
   Self-caught one command later (grep showed 0 lines), redone properly
   (53 lines + content match). This is the nullglob phantom-green class in
   miniature and it shipped in my own hands. Harvested as a convention row.
2. **Two broken extraction attempts before the good one** (awk `..$` pattern
   didn't match; sed `s/'''/'/` unterminated) — sloppy one-liners under a
   storming machine; the good version (line-range sed + targeted unescape)
   took one try once I stopped being clever.
3. **Watcher #3's verdict is lost** (§0.1) — armed a self-firing automation
   whose only log sink dies with the session. Design flaw, not bad luck.
4. **Watcher horizon escalation was backwards**: #1 got 40 min against a
   storm already 1.5h old; #2 60 min; #3 2h. Should have started long.
5. **Report typo "tod-o gates"** in the 07-42 report (caught + fixed, but
   it shipped in first write).
6. **A "verification" grep that couldn't match the real rendering**: my
   `^path=` check on the deployed runner unit returned empty tonight and I
   ALMOST reported the fix missing — the option renders as
   `Environment="PATH=…"`. Rule (already house doctrine, violated anyway):
   probe the surface the config actually lands on; when a verification
   returns empty, suspect the probe before the world.

## e) WHAT WE SHOULD IMPROVE

1. **Self-firing automation verdict persistence** — every self-firing
   automation appends `{timestamp, trigger, action, rc, verification}` to
   `~/.local/state/<name>.log` or `logger -t` BEFORE exiting (harvested
   [ready]).
2. **Degenerate-artifact guards in verifiers** — non-degeneracy assertion
   (line count / anchor content) before any pass verdict over extracted
   text (harvested [ready]).
3. **Unattended-deploy policy needs an owner ruling** — background
   self-firing of `nix run .#deploy` is powerful (the gate re-checks at
   switch; worst case rc=12) but unsupervised (harvested [decision]; also
   §g.1).
4. **Pre-edit content-pin discipline in a shared tree** — check
   `git status` + fresh-read the target BEFORE every edit, not after the
   tool's staleness refusal (three refusals this session, three recoveries,
   zero damage — but the discipline should be proactive).
5. **Watcher horizons**: start at the longest justified window; escalate
   the TRIGGER strictness instead of the horizon.
6. **Explicit question-closure**: when a prior report's open questions are
   answered by events/instructions, close them in one named place (§g).
7. **The gate's corpse-pile classifier** (mislabeled live churn as phantom;
   05-43 §7.5) — already harvested; standing reminder that a single
   disk-busy snapshot cannot classify pressure.
8. **cgroup io.stat one-liner was wrong** (empty output, abandoned for the
   process census) — keep a VERIFIED snippet in the ops docs or drop the
   approach.

## f) Up to 50 things to do next (priority-ordered)

1. Owner: run `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh`.
2. Confirm script output: mirror exists, Actions enabled, both tokens
   stored, sync-token file 0600, mirror-sync refreshed, dispatch 204.
3. Watch first CI run to green (`forgejo.home.lan/lars/eventcatalog-hub/actions`).
4. Triage any failure against the watch-list (nix-daemon reachability for
   the DynamicUser runner, `npm` in job env, GOPATH/GOMODCACHE writability).
5. Confirm the `dist` branch exists post-run.
6. If job-token push 403s: wire `PUSH_TOKEN` (write PAT) per the workflow
   fallback and re-run.
7. `sudo cat /var/lib/forgejo/.eventcatalog-hub-setup/sync-token` → sops
   paste into `platforms/nixos/secrets/architecture-catalog.yaml`
   (`ARCHITECTURE_CATALOG_SYNC_TOKEN=<hex>`), env-file format.
8. Deploy (any next `nix run .#deploy` — sops rotation restarts the sync
   unit).
9. `sudo systemctl start architecture-catalog-sync` (converge now).
10. Verify sync journal: "serving generation <stamp>".
11. Verify `/var/lib/architecture-catalog/current/index.html` +
    `build-stamp.json`; generations pruned to 3.
12. Verify collector flips `dist_present 1`, `fresh 1`, `stamp_age ≥ 0`.
13. Verify Gatus "Architecture Catalog" green (200 + EventCatalog title).
14. Verify Gatus "Architecture Catalog llms.txt" green.
15. Verify Gatus "Architecture Catalog Freshness" green.
16. Browser-probe `https://catalog.home.lan/` end to end.
17. Re-run `nix run .#post-deploy-check` — §15 stops warning.
18. In the same closeout: `trash /mnt/buildcache/scratch/eventcatalog-t0/`
    (2.7G scratch DECISION release).
19. Hub TODO [owner] item → [x]; sweep SystemNix TODO catalog rows.
20. AGENTS.md catalog header: drop "deploy owner-gated" → LIVE state; hub
    README gets the LIVE banner; runbook pre-go-live section under LIVE.
21. Push the hub repo (2+ commits) — keeps GitHub↔Forgejo mirror coherent.
22. Verify homepage tile renders (registry `homepage` field).
23. Verify system-health monitored-unit row rendered for
    `architecture-catalog-sync` (deferred twice — needs eval or root probe).
24. Verify the new WARN text rendered post-810 is superseded by real
    serving (the PLACEHOLDER skip line disappears from the hourly journal).
25. Post-green: confirm nightly 03:23 CI keeps freshness inside the 36h
    budget for one full cycle.
26. Post-green: end-to-end latency measurement (trivial hub change →
    mirror → CI → dist → sync).
27. Watch-list: `python3 merge.py` strict gate passes on real mirrors.
28. Watch-list: stale-sources workflow red-by-design doesn't page Discord.
29. Owner decision: hub CI-failure notifications → Discord at all?
30. Root sweep of the 7 mktemp leftovers in the textfile dir + standing
    retention mechanism (harvested row).
31. Implement the automation-verdict persistence convention (harvested row;
    CONTRIBUTING + tq runbook).
32. Implement the degenerate-artifact guard convention (harvested row).
33. Rule on the unattended self-firing deploy policy (harvested [decision];
    §g.1).
34. Implement the pressure-gate multi-sample busy window (pipeline row from
    Sep 30).
35. Implement the /tmp one-shot agent-script guard (pipeline row from
    Sep 30).
36. `architecture-catalog` VM test (services.md [ready] row).
37. SigNoz dashboard tile for `stamp_age` trend (services.md [watch] row).
38. Confirm forgejo mirror-sync output for `lars/bank-sync`, `lars/cqrs-htmx`,
    `lars/go-cqrs-lite` (source freshness for the first build; needs auth).
39. Investigate the rotating D-state `kworker/*+events_unbound` pattern once
    idle (§f.37 of 05-43; autofs-wedge class rule-out).
40. Second nightly build freshness check (end-to-end timer chain proof).
41. Post-go-live: annotate the 05-43/07-42/this report with a STATUS: LIVE
    pointer row at top.
42. Long-term: `catalog.index.json` structured diff gate (hub TODO [ready]).
43. Long-term: adopt the architecture gate in bank-sync/cqrs-htmx PR CI
    (hub TODO [blocked:upstream]).
44. Optional: verify the toggle surface for the CI-token rotation warning in
    setup script output on a re-run (rotation semantics claimed, re-run
    never executed live).
45. Consider a PSI-watch cadence doctrine note: the 3-consecutive-sample
    anti-dip trigger + horizon-first arming (codify what worked).
46. Decide whether tq pool agents should route one-shot scripts through a
    bounded wrapper (folds into the /tmp guard row's ask).
47. Sweep my own §f items here into TODO_LIST/service rows per doctrine —
    DONE for the durable ones (4 pipeline rows + services.md go-live row
    updated at authoring); the post-go-live chain (1-21, 37-43) lives in
    the services.md row + this report by design (owner-gated, not
    queue-harvested).
48. After the go-live: archive the go-live prep trio of reports (05-43,
    07-42, this) into the resolved state with one-line outcome banners.
49. Keep the crush-config lessons mirror in mind for #2/#32 (cross-project
    lessons file, committed THERE, not here).
50. Self-check: re-read this report's §d against the next session's reality
    — the false-green and the lost-verdict are the two failure classes to
    not repeat.

## g) Up to 3 questions I cannot answer myself

1. **Unattended self-firing deploy policy**: watcher #3 was armed to fire
   `nix run .#deploy` on its own judgment (gate-guarded). It died unfired,
   and a parallel actor deployed at 15:48 anyway. Do you sanction gate-
   guarded unattended deploys as a pattern (I keep the trigger strict and
   the verdict persistent), require per-occurrence authorization, or ban
   background self-firing of switches?
2. **Hub push timing**: the hub repo holds 2+ unpushed commits (fixed setup
   script + README). Push now (keeps GitHub↔Forgejo coherent; the Forgejo
   mirror will be created from the pushed state by the setup script), or
   hold until after the first green CI? The local checkout is sufficient
   for the go-live either way.
3. **Cross-session IO coordination**: the box sat at io PSI avg10 12-77%
   for ~3.5h during my deploy window (10× golangci-lint + builds + VM
   tests), and avg300 is still ~50% at 02:08. Is there an owner-level
   preference for how parallel sessions coordinate heavy work (tq slots,
   workload-admission `heavy-job`, deploy deferral etiquette), or is
   per-session judgment under the existing gates the intended steady
   state? I cannot see other sessions' priorities or deadlines.

## §f disposition (harvest doctrine)

Durable new asks harvested AT AUTHORING: textfile retention, automation-
verdict persistence, degenerate-artifact guard, unattended-deploy policy
(pipeline.md ×4, `HARVESTED at authoring`); services.md go-live row updated
in place (prerequisite DONE). Go-live owner chain (items 1-21) lives in the
services.md row + §f here — deliberately NOT queue-harvested (owner-gated,
not agent-actionable; the queue carries `[ready]` one-liners only).

## Evidence pointers

- Deployed runner unit:
  `/etc/systemd/system/gitea-runner-evo\x2dx2.service` line 11
  `Environment="PATH=…nix-2.34.8…jq-1.8.2…python3-3.14.7…"`.
- Profile: `/nix/var/nix/profiles/system-810-link` →
  `…26.11.20260928.7a0f122`, linked Sep 30 15:48.
- Sync journal (hourly): PLACEHOLDER skip carrying the sync-token path WARN.
- Collector: `architecture-catalog.prom` honest zeros (`dist_present 0`,
  `fresh 0`, `stamp_age -1`, `scrape_errors 0`).
- Hub: HEAD `5ec04cd`, clean, 2 unpushed (`origin/master..HEAD`).
- Watcher series: heartbeats in the 07-42 report §2; #1 gave up 07:38,
  #2 08:38 (08:08 dip refused), #3 armed 08:39, buffer lost to the session
  gap, given-up banner would have been ~10:39.
- PSI at resume: `some avg10=34.97 avg60=41.03 avg300=50.31` (02:08).
