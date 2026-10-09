# Status: GeoMetrikks zero-ingestion fix session — 2026-10-07 13:11 CEST

**Session scope:** one user question ("Why does Geometrikks can't read data from Caddy?") →
root-cause → in-tree fix → verification → docs/queue surfacing. No other domains touched.
Report written per the user's explicit `.md` format demand (status-report skill default is
HTML; user instruction wins — flagged in the closing message).

**Headline:** GeoMetrikks has ingested **zero events since its 2026-09-29 native flip** because
its unit was granted a capability in the way that only works for root processes. The class was
learned on 2026-09-06 (mail-relay) but its "document in AGENTS.md/systemd gotchas" follow-up
never landed, so it repeated here 13 months later. Fixed in-tree; **deploy-gated** (owner runs
`nix run .#deploy`). The UI Logs page currently 500s in prod and the map is empty until then.

---

## a) FULLY DONE

| #  | Item                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Proof                                                                                                                   |
| -- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| a1 | **Root cause proven end-to-end** — journal `PermissionError: [Errno 13] … '/var/log/caddy/access.log'` on `/api/v1/logs/files` (HTTP 500, 12:28–12:30 live) + every ingestion run ending `Total processed: 0` (first successful start 02:01 post-MaxMind); deployed unit grep: `CapabilityBoundingSet=CAP_DAC_READ_SEARCH`, `User=geometrikks`, **no `AmbientCapabilities` line**; app source (store env, v0.19.0) confirms split behavior: tailer swallows per-file `OSError` (logparser.py:445/680/718 → silent 0 events) while `logfiles.py:97` `Path.is_file()` propagates EACCES (pathlib ignores ENOENT/ENOTDIR only) → loud 500 | journal + `/etc/systemd/system/geometrikks.service` + store `geometrikks/services/{logfiles.py,logparser/logparser.py}` |
| a2 | **Fix landed** — `modules/nixos/services/geometrikks.nix`: `AmbientCapabilities = "CAP_DAC_READ_SEARCH"` added beside the bounding set inside `harden{}` (passthrough verified in lib/systemd.nix `removeAttrs` forwarding); false "cv-backup precedent" comment corrected (cv-backup is a ROOT process — bounding set grants there, nowhere else)                                                                                                                                                                                                                                                                                     | module diff                                                                                                             |
| a3 | **Rendered-unit verification** — `nix eval .#nixosConfigurations.evo-x2.config.systemd.services.geometrikks.serviceConfig.{AmbientCapabilities,CapabilityBoundingSet}` both return `"CAP_DAC_READ_SEARCH"`, `NoNewPrivileges=true` (ambient caps survive NNP on kernel 7.x; caddy binding 80/443 as user caddy is the standing live precedent)                                                                                                                                                                                                                                                                                         | eval output in session                                                                                                  |
| a4 | **All gates green** — `nix flake check --no-build`: "all checks passed" (aarch64-darwin omission = documented expected warning); `nix fmt` on the module: 0 changed                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | gate output                                                                                                             |
| a5 | **Runbook corrected** — `docs/services/geometrikks.md` Logs bullet: cap pair + grant-vs-limit lesson + dates; also fixed the stale `ProtectSystem=strict` claim (rendered unit says `full`, harden's default)                                                                                                                                                                                                                                                                                                                                                                                                                          | runbook diff                                                                                                            |
| a6 | **CHANGELOG entry** — [Unreleased]/Added bullet with root cause, fix, post-deploy proof contract                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | CHANGELOG.md                                                                                                            |
| a7 | **Queue hygiene on both surfaces** — geometrikks post-deploy smoke-probe row extended (TODO_LIST + services.md) with the 2026-10-07 addendum: assert rendered `AmbientCapabilities` AND journal processed-events > 0                                                                                                                                                                                                                                                                                                                                                                                                                   | both files                                                                                                              |
| a8 | **Missing gotcha landed (found during this report's self-check)** — `docs/agents/systemd.md` had ZERO `AmbientCapabilities` mentions; the 2026-09-06 report's queued item 28 ("Document AmbientCapabilities-vs-BoundingSet in AGENTS.md systemd gotchas") was never harvested — added the canonical bullet today, with probe commands (`systemctl show -p AmbientCapabilities`, `/proc/<pid>/status` `CapEff`)                                                                                                                                                                                                                         | `rg -in AmbientCapabilities docs/agents/systemd.md AGENTS.md` was empty pre-edit                                        |
| a9 | **Interim report** — `docs/status/2026-10-07_12-35_geometrikks-zero-ingestion-ambient-cap-fix.md` (evidence + fix narrative; this report supersedes it as the session close-out)                                                                                                                                                                                                                                                                                                                                                                                                                                                       | file                                                                                                                    |

## b) PARTIALLY DONE

| #  | Item                                                                                                                                                                                                                                                                                                                                                                                                                                                | State                    |
| -- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| b1 | **The fix itself** — tree correct, runtime still broken. Ingestion is running right now with `Total processed: 0` and the Logs page 500s until the owner deploys. Every Nix gate passed; zero runtime effect yet.                                                                                                                                                                                                                                   | deploy-gated             |
| b2 | **Capability-grant class sweep** — sibling units with the same latent shape (DAC-class caps in `CapabilityBoundingSet`, non-root `User=`, no `AmbientCapabilities`) were NOT swept. Candidates noticed in passing, unverified: `storage-collector.nix` (Ambient=`CAP_FOWNER` only, Bounding adds `CAP_DAC_READ_SEARCH` — is its user root?), `browser-history.nix` backup legs (likely root — likely fine, unverified). Queued as [ready] (see f3). | identified, not executed |
| b3 | **Regression pin** — the fix is verified by a MANUAL `nix eval` only; no eval test pins the render (the repo pattern, e.g. `tests/test-harden-lifecycle.nix` pinning harden shapes, would prevent silent loss of the grant). Queued (f4).                                                                                                                                                                                                           | identified, not written  |

## c) NOT STARTED

| #  | Item                                                                                                                    | Note                    |
| -- | ----------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| c1 | Post-deploy runtime verification — journal processed-events > 0, `/api/v1/logs/files` → 200, map populates, Gatus green | blocked on owner deploy |
| c2 | Upstream filings against `GilbN/geometrikks` (see f5) — needs the verify-before-filing gate first                       | not started             |
| c3 | Data-plane Gatus check (fail-closed on event-count delta) — pre-existing `[ready]` row, untouched this session          | services.md:227         |
| c4 | Geometrikks smoke probe implementation — pre-existing `[ready]` row, extended not implemented                           | services.md:226         |

## d) TOTALLY FUCKED UP

| #  | Item                                                                                                                                                                                                                                                                                                                                                                                                  | Why it deserves the label |
| -- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| d1 | **The 2026-09-29 native flip shipped a capability config that granted NOTHING** — `CapabilityBoundingSet` alone on a non-root unit is a no-op grant; 8+ days of a green-looking service with a stone-dead data plane. The module comment even DOCUMENTED the wrong mental model ("cv-backup precedent" — a root process).                                                                             | the bug itself            |
| d2 | **The 2026-09-06 lesson was learned and then lost** — the mail-relay report queued "document AmbientCapabilities-vs-BoundingSet in AGENTS.md/systemd gotchas" as follow-up 28; it was never harvested, the gotcha never landed in `docs/agents/systemd.md` (verified absent today), and the class repeated 13 months later in a second service. A repo-level memory failure, not a knowledge failure. | the meta-bug              |
| d3 | **The failure is invisible to every existing gate** — `/health/ready` 200, `ingestion_started` clean, unit active, Gatus registry check green; only a human opening the Logs page (500) or reading `Total processed: 0` sees it. The mmdb blocker masked it until 2026-10-06, then it became THE blocker with zero alarm.                                                                             | detection gap             |
| d4 | Not fucked up: my fix path — all gates green on first pass, no dominoes, no shared-tree incidents with the parallel sessions (their uncommitted todo edits + untracked report were left untouched).                                                                                                                                                                                                   | honest counterpoint       |

## e) WHAT WE SHOULD IMPROVE

1. **Make the grant-vs-limit class eval-impossible**: extend the audit layer (systemd-shape-audit class) to throw (or pre-deploy-check to fail) on `CapabilityBoundingSet` containing DAC-class caps + non-root `User=` + no `AmbientCapabilities`. Today it's a comment; comments don't compile.
2. **Pin capability renders in eval tests** for every unit that relies on caps to function (geometrikks first) — the rendered unit is the contract.
3. **Health endpoints are not pipeline probes** — geometrikks proved it twice (mmdb class, cap class). The fail-closed data-plane Gatus row should become the doctrine for every log/metric-ingest service.
4. **"Document X in AGENTS.md" follow-ups need a landing check at harvest time** — they're the easiest items to lose because the queue row says "doc" and the dispatcher skips doc-shaped work (d2).
5. **Smoke probes should assert rendered unit properties** (`AmbientCapabilities`, caps, env), not just liveness — the smoke row now says so; apply the pattern to the next service that gets one.
6. **Runbook claims about rendered serviceConfig should be grep-verified at authoring time** (the `strict`-vs-`full` drift survived two reviews) — the AGENTS.md queue-author spot-verify rule applies to runbooks too.
7. `check-todo-system.sh` strict mode reports 86 foreign unharvested §f reports — a batch annotation/harvest session would restore the signal.

## f) NEXT: up to 50 things (session-scoped, impact-sorted)

Legend: `[new]` = harvested to queue/library NOW with this report as Source; `[row]` = already
queued (cite, don't duplicate); `[roadmap]` = brainstorm fuel, deliberately not harvested;
`[blocked:deploy]` = owner-gated. Sections f-items 1–5 are the direct follow-ups this report
self-harvests; the rest are honest smaller items noticed in-session.

1. `[blocked:deploy]` **Deploy train** — carries the AmbientCapabilities fix (+ ~15 other landed fixes per the 10-06 Pareto plan). THE unblock for everything below.
2. `[row]` **Post-deploy geometrikks verify** — journal events > 0, `/api/v1/logs/files` 200, map populates; folds into the extended smoke row (services.md:226).
3. `[new]` **Capability-grant class sweep** — find every unit with DAC-class `CapabilityBoundingSet` + non-root `User=` + no `AmbientCapabilities`; deliver as eval audit or pre-deploy §14 + post-deploy `systemctl show -p` probe (b2).
4. `[new]` **Pin geometrikks capability render in an eval test** (b3; extend tests/test-harden-lifecycle.nix's harden passthrough coverage).
5. `[new]` **File upstream geometrikks issues** (verify-before-filing first): (1) `/api/v1/logs/files` 500 with raw `PermissionError` when a configured path is unreadable — should mark the entry `available=false` like ENOENT; (2) tailer swallows per-file `OSError` with no warning/counter — unreadable pipeline is indistinguishable from an idle one.
6. `[row]` Geometrikks ingestion data-plane Gatus check (services.md:227) — the durable guard for d3.
7. `[row]` Geometrikks post-deploy smoke probe implementation (services.md:226).
8. `[row]` Persist geometrikks OIDC scripts fixture as a flake check (services.md:228).
9. `[row]` Geometrikks docker-era volume removal after ≥48h green (services.md:154) — reset the 48h clock to the deploy date once f1 lands.
10. `[blocked:deploy]` Annotate the 12-35 fix report + this report with live proof post-deploy (ANNOTATE mode, no rewrite).
11. `[roadmap]` Sweep runbooks for rendered-vs-documented serviceConfig drift (ProtectSystem/caps/env claims) — the strict-vs-full catch suggests a class.
12. `[roadmap]` Document the capability debugging recipe in one place (gotcha bullet now carries it; consider a scripts/cap-probe helper).
13. `[roadmap]` harden{} docstring: state the grant-vs-limit contract where contributors will actually read it (lib/systemd.nix header).
14. `[roadmap]` Post-deploy: confirm sops `restartUnits` fired on the geometrikks rotation (10-06 report item 30) — same deploy window.
15. `[roadmap]` Sanity-check the 74-file tail list (1 global + 73 vhosts) for duplicate basenames/stale vhosts — listing dedups by basename, ingestion may double-count.
16. `[roadmap]` Consider exposing ingestion freshness as a textfile collector (generic "log-ingest liveness" pattern beyond the Gatus row).
17. `[roadmap]` Batch-harvest/annotate the 86 foreign unharvested §f reports (e7) — restores guard signal.
18. `[roadmap]` When the next cap-reliant service lands, copy the geometrikks unit shape (Ambient+Bounding pair, commented) — pattern propagation.
19. `[roadmap]` FEATURES.md geometrikks row: add "ingestion dead 09-29→10-0x, root cause AmbientCapabilities" once live-verified — honest inventory.
20. `[roadmap]` After a green week: revisit whether `CAP_DAC_READ_SEARCH` is still the right grant vs group-read perms (0600→0640 caddy group) — defense-in-depth tradeoff, owner decision.

(Stopped at 20 honest items; padding to 50 would fabricate work. Items 6-9 are pre-existing
queued rows re-cited for one-glance completeness.)

**Self-harvest record (per AGENTS.md dispatch rule):**

- f3 → `[ready]` row added to `docs/todo/services.md` + `TODO_LIST.md` one-liner (Source: this report).
- f4 → `[ready]` row added to `docs/todo/services.md` + `TODO_LIST.md` one-liner (Source: this report).
- f5 → `[ready]` row added to `docs/todo/upstream.md` + `TODO_LIST.md` one-liner (Source: this report).
- f10, f19 → `[blocked:deploy]`/post-live — **deliberately not harvested now**: harvesting a future
  annotation task for a report written minutes ago creates a row that can only be closed after f1
  anyway; the smoke row (f2) already carries the post-deploy obligation on both surfaces.
- f11-f18, f20 → **deliberately not harvested**: roadmap-fuel / existing-row citations / owner
  decisions — per the TODO System rule that vague or pre-tracked items stay out of the queue.

## g) QUESTIONS I CANNOT ANSWER MYSELF (max 3)

1. **Deploy now?** The fix is one capability line but the UI is visibly broken (500 on Logs, empty
   map) and the train carries ~15 other landed fixes. Do you want `nix run .#deploy` in this
   window, or should the train wait for the next quiet window?
2. **Sweep strictness (f3):** eval-time audit that THROWS (hard gate, catches future units at
   `nix flake check`, costs exemptions for legitimate root units) or pre-deploy/post-deploy script
   probes (softer, catches at deploy)? My lean: eval audit modeled on systemd-shape-audit — your call.
3. **Upstream (f5):** file the two geometrikks issues on GitHub (GilbN/geometrikks) now — with the
   EACCES repro from this host — or hold until the fix is live and we've confirmed behavior
   post-grant (the 500 repro disappears after deploy, so filing first preserves the live repro)?

---

**Surfaces touched this session:** `modules/nixos/services/geometrikks.nix`,
`docs/services/geometrikks.md`, `CHANGELOG.md`, `TODO_LIST.md`, `docs/todo/services.md`,
`docs/todo/upstream.md`, `docs/agents/systemd.md`,
`docs/status/2026-10-07_12-35_geometrikks-zero-ingestion-ambient-cap-fix.md`, this report.
Untouched by me: the parallel sessions' dirty files (`docs/todo/{monitoring,pipeline,upstream}.md`
— note: upstream.md receives my new row → append-only edit away from their edits, content-pinned
at `f9565ea5` before both writes).

## ADDENDUM 2026-10-07 ~16:40 — ALL THREE QUESTIONS ANSWERED BY EXECUTION (same session)

Owner's directive: "Execute and Verify them one step at a time… until done." The three
pending questions resolved as: (1) deploy NOW — done, live-verified (see the 12-35
report's addendum: system-837 anchored, CapEff 0x4 kernel-granted, 61 files streaming,
zero mislabels/500s); (2) capability-sweep as EVAL-TIME audit — built
(`modules/nixos/services/capability-grant-audit.nix`, 4-leg extendModules matrix proven,
zero current offenders — resolves this report's §b2 unverified candidates:
storage-collector CLEAN, browser-history legs root); (3) upstream filed PRE-deploy —
[#301](https://github.com/GilbN/geometrikks/issues/301) + [#302](https://github.com/GilbN/geometrikks/issues/302),
evidence captured while the repro was live. §f4's eval pin landed as
`checks.x86_64-linux.geometrikks-caps` (5 cases incl. audit-wiring).

**Correction to §a1 (the one wrong cell in this report):** "tailer swallows per-file
OSError → silent 0 events" is FALSIFIED. v0.19.0 logs unreadable files at ERROR as
`Log file does not exist: … - waiting for it to appear` (370× on 10-07; `access.log`
reported "does not exist" 5× while the HTTP path proved it exists via Errno 13). The
verify-before-filing gate caught it: the drafted "silent swallow" issue was retracted
pre-publication and refiled as the EACCES-mislabel issue #302. §b3's pin gap: closed.
