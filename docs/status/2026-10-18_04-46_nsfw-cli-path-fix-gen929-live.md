# Session Report: "fix it!" — the `nsfw` CLI, the I/O-storm gate, and the gen-929 discovery

**Session window:** ~02:35 → 04:46 CEST, 2026-10-18
**Authoring time:** 2026-10-18 04:46 CEST
**Scope discipline (owner directive):** report covers ONLY this session's work + what was observed live along the way. No corpus research. Parallel-session work is recorded as OBSERVED, not owned.

---

## Headline

The `nsfw` command is **LIVE on PATH** (`/run/current-system/sw/bin/nsfw`, `nsfw --version` → `2a88f3e`) — but not via my deploy. My in-tree fix (one `environment.systemPackages` leg in the nsfw-classifier module) was fully built and gate-verified by me; a **parallel session's 04:19 deploy (gen-929)** then carried it, because the flake builds from the shared working tree. My own switch attempt was **blocked by the deploy entry gate** on a rotating I/O storm (inboxclean-web → monitor365-server → forgejo, the last reading 473–573 MB/s) — I refused the force override, and the refusal turned out moot. The same parallel deploy **bumped the nsfw-classifier input to `2a88f3e`** (was `c6113ce`-era), which restarted the unit at 04:27:27: it is mid cold-start until **~05:42** (74m50s economics).

One honest self-inflicted incident, caught and repaired in ~60 seconds: a sloppy CHANGELOG edit briefly clobbered the parallel session's entry title (restored verbatim; final diff = +2 lines). Details in §d/§e.

---

## a) FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| 1 | **`nsfw` CLI on PATH, live-verified** | `command -v nsfw` → `/run/current-system/sw/bin/nsfw`; `nsfw --version` → `2a88f3e`; `nsfw --help` renders the cmdguard UI with all subcommands (classify / benchmark / batch-report / evaluate / human-review / latency-bench + faces / parts / immich / history) |
| 2 | **The fix itself: one module leg** | `environment.systemPackages = [ cfg.package ];` under `mkIf cfg.enable` — modules/nixos/services/nsfw-classifier.nix:201. Pattern-matched to tq-agent-pool.nix:268 / hermes.nix:599 / file-and-image-renamer.nix:96. Installs the SAME ROCm-wrapped package the unit runs (identical ONNX Runtime wrapping), plus the `nsfw-server`/`nsfw-classify`/… compat shims |
| 3 | **Zero-cost claim verified** | Package was already in the closure (the unit's ExecStart references it) — `ls` of the store path shows `bin/nsfw` + 7 shims cached; no new derivations, no FODs (§11 confirmed "all deploy go-modules FODs cached") |
| 4 | **Full verification chain** | `nix flake check --no-build` green (all eval audits pass, incl. the tile-icon and pin audits); targeted eval proves `environment.systemPackages` carries `nsfw-classifier-go-rocm`; full toplevel eval green (assertions pass; only the other waves' pre-existing warnings) |
| 5 | **Pre-deploy battery green** | `nix run .#pre-deploy-check` → **103 passed, 8 warnings, 0 failed** ("safe to deploy") — including §15 evidence gate and §16 tile icons |
| 6 | **Docs surfaces updated** | Runbook Ops bullet (CLI on PATH + "don't run a second server" warning) in docs/services/nsfw-classifier.md; CHANGELOG entry written (and the parallel entry restored intact after my clobber) |
| 7 | **Deploy-entry-gate forensics** (storm attribution while blocked) | Per-cgroup `io.stat` diffing isolated the churn: `inboxclean-web` 42 MB/s reads, `monitor365-server` 46 MB/s writes (both collapsed to 5.4/9.4 within 30 s — transient bursts), then `forgejo` **473–573 MB/s reads**. Correctly classified as the crash-#3 full-disk-reader class; **did not force** (`DEPLOY_FORCE_PRESSURE=1` declined) |
| 8 | **Anchor discipline after the foreign deploy** | `readlink /run/current-system` == `system-929-link` target (`qaf5mm56…`) — gen-929 properly anchored |
| 9 | **Daemon-sweep audit** | My two files landed inside heuristic daemon commits (`f640be0f7`, `a357d1ee2`) interleaved with other sessions' files; content verified intact at line 201; **no amend attempted** (interleaved history + daemon-race policy — amend would absorb foreign files) |
| 10 | **At-authoring-time harvest** | docs/todo/services.md row 285 updated: gen-929 input-bump restart recorded, row unblocked `[blocked:deploy]` → `[ready]`, Source pointer to this report |

## b) PARTIALLY DONE

1. **"Deploy it and verify" — the original completion bar.** The command is live, but via the parallel session's deploy, not mine. My switch attempt never ran (moot: would have been a no-op re-switch). The end state is verified, so this is process-partial, not outcome-partial.
2. **nsfw service availability at rev `2a88f3e`.** The unit restarted 04:27:27 (input bump) and is warming until ~05:42. Port 8104 bound, unit active/running — but `/readyz` green + one classify + gatus conditions at the NEW rev are **not yet verified** (that is exactly the row-285 battery, now unblocked).
3. **Runbook currency.** I added the CLI bullet, but the runbook still carries `c6113ce`-era facts while the server is `2a88f3e` (row 281 "runbook lags live server surface" — still open, now one rev staler). Did not reconcile: not my wave's change, and the owner directive scoped me to my session.

## c) NOT STARTED (all pre-existing, validated still-open this session — not mine to start without dispatch)

1. **gen-929 post-deploy battery legs** (row 285, `[ready]` as of this report): readyz green, one classify + skin/face smoke, extension re-pair/fingerprint, gatus incl. RESPONSE_TIME, §17 memory.events sweep — all against `2a88f3e` after ~05:42.
2. **TimeoutStartSec is still INERT** (row 286): live unit line 6 confirms `TimeoutStartSec=10min` in `[Unit]` — systemd ignores it; measured cold start 74m50s; the ≥90min `serviceConfig` re-budget is unstarted. Tonight's restart is yet another live demonstration.
3. **Caddy nsfw vHost upstream-response timeout** (row 288, `[decision]`): warmup-phase clients still spin forever instead of fast-504.
4. **Runbook "Startup timeline" section** (row 289): still absent; tonight produced another data point (04:27:27 start → expect `server warmup complete` ~05:42).
5. **`/inject/filter.js` existence never verified** (row 1193), **runbook server-surface table lag** (281), **optionify the hardcoded `/home/lars` defaults** (282/526), **de-dev-ification** (280), **`/readyz` token LAN-trust decision** (273), **cbor-unreadable hydration events** (287), **negative-test the two eval cases** (283), **pre-deploy model-sanity gate leg** (284). All untouched by me; all re-confirmed open.

## d) TOTALLY FUCKED UP

1. **The CHANGELOG clobber (self-inflicted, caught in ~60 s, zero net damage — but the CLASS is unacceptable).** My retry edit's `old_string` was `---\n\n- **Deploy blocker cleared + two boot-path defects found: … (2026-10-18)**` and my `new_string` did NOT carry the foreign title — deleting the parallel session's entry header and fusing its body onto my entry. Root cause: under a known concurrent-edit regime I still constructed a replace-block that SPANNED foreign text instead of a surgical insert anchored only on my own lines. Caught because I re-viewed the seam immediately (per discipline); restored verbatim; `git diff` = +2 lines. **Lesson encoded in §e.**
2. **I attempted a deploy on a shared tree without reconciling "is master already deployed?"** — the real forget, detailed in §e-1. The gate caught the I/O half; the mootness I only discovered 25 minutes later via journal + deploy-log archaeology. No damage landed (blocked switch = no switch), but a deploy had it NOT been gate-blocked would have re-shipped gen-928 → 929 content mid-storm as a "my change" deploy.
3. Nothing else in the session qualifies. No data loss, no prod harm, no secret exposure, no force-flags used, no foreign work destroyed.

## e) WHAT WE SHOULD IMPROVE (brutal answers, self-review questions folded in)

1. **THE forget: I read the parallel session's "Deploy blocker cleared" CHANGELOG entry at 03:55 and still launched my own deploy at 04:10** without once asking "was the tree already deployed after that?" The deploy logs (`/var/log/systemnix-deploys/`: 03:03, 03:06, 04:19) and `ls -t /nix/var/nix/profiles/` were one command away the whole time. **Improvement: a PRE-deploy premise check** — before `nix run .#deploy`, reconcile latest deploy log + latest `system-N-link` against HEAD delta; if a parallel deploy is younger than your edit, probe what IT carried first. Candidate: fold into deploy.sh entry output (print "latest deployed gen + its commit" next to the PSI gate). This is the same premise-check family the TODO system already codifies for queueing — it just has no deploy-time enforcement.
2. **Edit construction under concurrency.** Rule going forward: an `old_string` must never span a foreign session's lines. Insert with an anchor that is exclusively mine; if a foreign line must appear in context, the new_string must reproduce it byte-identical. (The 2026-10-17 direnv/jq lesson pattern: the environment is adversarial; write edits that fail safe.)
3. **"No unit restart" claims need deploy-scope caveats on a shared tree.** I correctly established MY leg changes no unit text — and said so. But on this box "my deploy" never ships only my change; the actual deploy restarted nsfw via the input bump. The honest phrasing I should have led with: "my leg is restart-free; whatever ELSE is in the tree at switch time is not covered by that claim."
4. **Wasted probes before the working storm attribution:** two sampler attempts produced empty output (io.stat `key=value` field parsing). Minor, but on a storming box at 4 AM, probe economy matters; the working one-liner (per-cgroup rbytes/wbytes delta) should have been attempt #1 — it is the documented `/proc`-forensics pattern from the session-discipline notes, io.stat edition.
5. **Gate friction is doing real work — keep refusing to force.** Standing improvement candidate: the entry gate already prints top-3 stalled cgroups; extending it with a per-service `io.stat` diff (the probe that actually named inboxclean/monitor365/forgejo) would turn every future block into a 5-second attribution instead of a 15-minute manual dig. Pipeline-candidate quality, owner call.
6. **Scope discipline held (good, preserve it):** did not touch TimeoutStartSec, cbor events, the forgejo storm, or the input bump's own verification duties — all flagged, none silently absorbed. Also did not amend interleaved daemon commits. These refusals were correct.
7. **Lying check (skill question): no.** Every headline claim in-session was live-probed (`--version`, `--help`, `command -v`, readlink, busctl, ss, journal). One phrasing got the §e-3 caveat above; nothing asserted as "can" that was only observed once ("happened" ≠ "can" respected).

## f) Up to 50 things we should get done next (24 honest items; `NEW` = born this session, `ref` = already queued — validated open, not re-harvested)

**New / harvested this session:**
1. `NEW → harvested` Run the **gen-929 battery legs** after ~05:42 vs rev `2a88f3e` (readyz, classify + skin/face smoke, extension re-pair/fingerprint, gatus incl. RESPONSE_TIME, §17 sweep) — docs/todo/services.md row 285, now `[ready]`.
2. `NEW` **Pre-deploy premise check** (deployed-gen-vs-HEAD reconcile, per §e-1) — as deploy.sh output or a checked discipline note in docs/CONTRIBUTING.md. Decision needed: enforcement vs convention.
3. `NEW` **Extend the entry gate with per-service `io.stat` diff output** (§e-5) — turns every future PSI block into instant attribution. docs/todo/pipeline.md candidate.
4. `NEW` **`io-storm-attribution` helper script?** The per-cgroup io.stat delta one-liner is reusable (crash-#3 class keeps recurring). Decision: scripts/ addition vs stay-ad-hoc (owner call; repo is deliberately shrinking scripts/).
5. `NEW` **Reconcile the nsfw TODO_LIST rows (510–516, 1193, 1247, 1267–1272) with the `2a88f3e` world** — several cite `c6113ce`-era premises; one reconciliation pass so the queue doesn't dispatch on stale revs (premise-check rule).
6. `NEW (upstream)` **Upstream nicety: `packages.nsfw` alias = CPU build** — `nix run .#nsfw` on this AMD host silently gives the CPU-wrapped binary (the 2026-10-15 incident class). Suggest alias → host-appropriate package or a warning in the alias description. docs/todo/upstream.md candidate.
7. `NEW (owner call)` **Compat shims on PATH hazard** — `nsfw-server` now resolves interactively; the runbook warns against casual second servers. Options: leave (dev convenience), or drop server shims from the PATH package copy. Owner call, low urgency.

**Already queued, re-validated open this session (refs):**
8. `ref` (286) TimeoutStartSec `[Unit]`-inert → `serviceConfig` + ≥90min re-budget (live-reconfirmed tonight, unit line 6).
9. `ref` (288) Caddy nsfw upstream-response timeout decision (tonight's warmup = another spin-forever window).
10. `ref` (289/1272) Runbook "Startup timeline" section (75-min normal silence signature).
11. `ref` (287) verdicts.db cbor-unreadable hydration events: count + classify + upstream.
12. `ref` (283) Negative-test the two eval cases (`full-ensemble-all-models`, `cold-start-timeout-budget`).
13. `ref` (284) Pre-deploy model-sanity gate leg (model.onnx + go_meta.json per key when `--all`).
14. `ref` (281/1247) Runbook + module header lag the live server surface (now one rev staler).
15. `ref` (274, folded into 285 pass) Gatus green on superb-audit conditions.
16. `ref` (273) `/readyz` pairing-token LAN-trust decision (owner).
17. `ref` (280) De-dev-ification: system user + ProtectHome + models out of the 0700 checkout.
18. `ref` (282/526) Optionify hardcoded `/home/lars` defaults (nsfw-classifier.nix:136 among the 6 sites).
19. `ref` (1193) Verify `/inject/filter.js` actually exists upstream.
20. `ref` (stability, crash-#3 class) Tonight's storm instances (inboxclean 42 MB/s reads, monitor365 46 MB/s writes, forgejo 473–573 MB/s reads) — the per-process heat/IO attribution row already queued in monitoring.md; these are three more data points for it.
21. `ref` (stability 305) Wrap dev-shell builds in heavy-job admission (validated still-open: the storm included non-admitted churners).
22. `ref` (upstream 142) sd_notify/Type=notify + `--rate-limit` upstream asks.
23. `ref` (services 285 sibling) Integration-registry RESPONSE_TIME tiering codification.
24. `NEW (tiny)` The runbook CLI bullet says "same ROCm wrapping" — if the owner ever flips `package` to the CPU build, that bullet auto-lies; consider wording tied to `cfg.package` instead of "ROCm". Cosmetic doc robustness.

(Stopped at 24 rather than padding to 50 — the remaining ideas were restatements of the above or outside this session's observed scope; per skill guidance, a larger N is a brainstorm, and fabrication is worse than a short honest list.)

## g) Questions I CANNOT figure out myself (3)

1. **Was the 04:19 gen-929 deploy — carrying the nsfw-classifier input bump to `2a88f3e` plus the monitor365 re-enable and tile-logo waves — your intended "ship tonight", or should the input bump get post-deploy scrutiny before we trust it?** I can attribute the mechanics (deploy log, lock diff, restart at 04:27:27) but not the intent; only you know whether `2a88f3e` was a deliberate bump or a lock side-effect of the wave.
2. **After ~05:42: do you want THIS session to run the unblocked row-285 battery legs live (readyz → classify → gatus → §17 sweep), or leave them to the dispatch queue?** I deliberately stopped at the owner gate; the legs are `[ready]` either way.
3. **Force policy for storm windows:** when a switch is provably zero-new-derivation (§11 cached, package in closure), is `DEPLOY_FORCE_PRESSURE=1` ever acceptable to you, or is the entry gate an unconditional hard stop? Tonight I treated it as unconditional; a policy answer makes that deterministic for every future night session.

---

## Observed-state appendix (live probes this session, for the record)

- `readlink /run/current-system` = `/nix/store/qaf5mm56wccqlqw5azhlgrgdrsqiaij1-nixos-system-evo-x2-26.11.20261014.55bfb4d` == `system-929-link` target. Deploy log: `/var/log/systemnix-deploys/2026-10-18_04-19-56.log` (parallel session). Boot 03:06:XX, no reboot since ("up 1:33" at 04:39).
- Unit: `ActiveState=active`, `SubState=running`; `ss -ltn` :8104 LISTEN (Recv-Q 47 at probe time — bound/accepting-or-backlogged mid-warm state); journal `Started nsfw-classifier … 04:27:27`; expected `server warmup complete` ~05:42 (74m50s prior-boot measurement).
- Deploy entry gate block (04:10): io PSI some avg10 50.97%, disk busy 101.3% (nvme1n1 + sdb at 101%); stalled cgroups: user@1000 app.slice ~89%, `app-niri-ghostty-8313.scope` 88.9% (victims, not causes — the causes were the system.slice services named in §a-7).
- 13 concurrent crush (agent) processes observed during the storm window; CHANGELOG mid-write collision + one untracked foreign planning doc = the two direct signs of the parallel session this session touched.
- Commit state at authoring: module + runbook committed (daemon, interleaved); CHANGELOG entry + services.md row-285 update uncommitted (daemon will sweep; per harness rule I do not commit).
