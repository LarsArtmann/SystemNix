# Session Report: "Why is https://nsfw.home.lan/ loading forever?" — Live Diagnosis + Self-Review

- **Session scope:** single live question, answered end-to-end with live probes; zero repo code changes; queue-surface harvest at authoring time (ledger at the end).
- **Session window:** ~01:05–01:55 CEST, 2026-10-18.
- **Headline answer (delivered live):** `nsfw.home.lan` spins forever because its backend — nsfw-classifier on :8104 — is mid-cold-start: the server binds its port immediately but serves HTTP only after a **74m50s** full-ensemble boot (~12 min model/store load with logs + **~63 min of silent warmup**, zero log lines by design). The unit restarted with tonight's 00:42:21 reboot (which the parallel session's 00:58 report identified as a **thermal-trip crash at 00:40:44**, boot `ee085387`). During warmup, TCP connects succeed into the kernel listen backlog (167 queued at first probe, 245 at report time) but no HTTP response ever arrives, and Caddy has no upstream response timeout — so the browser spins instead of erroring.
- **Standing warning delivered:** do NOT restart the unit — every restart resets the ~75-min clock. Predicted ready ≈ **01:57:30** (74m50s after the 00:42:40 start). *Unverified at authoring time (01:53); close-out probe queued as §f.1.*

---

## a) FULLY DONE

| # | Item | Evidence (all live-probed this session) |
| - | ---- | --------------------------------------- |
| 1 | **Root cause of the infinite load, chain proven end-to-end** | DNS `nsfw.home.lan → 192.168.1.150` (getent); Caddy listening :80/:443 on both LAN IPs; port 8104 `LISTEN` with growing accept backlog (167 → 245), process alive; reference boot logged `port bound, loading models` at 00:42:44 and `server warmup complete elapsed_ms=3776395` only at 19:28:46 on the previous boot (74m50s start→listening) |
| 2 | **Healthy-progress vs hang discriminated** | pid 1441 at 188–192% CPU continuously (CPU time 1h19m → 2h09m across samples), RSS 5.5–5.9G vs 16G cap, cgroup `memory.events` all zero (no low/high/max/oom) — working, not deadlocked or throttled |
| 3 | **Restart-history forensics, full evening reconstructed** | Oct 17 12:10:18 clean stop ("Stopping"/"Deactivated successfully"); 18:13:56 boot `ee085387` start; 23:30:04 clean stop + restart 9 s later (graceful, deliberate — NOT a crash, NOT periodic); 00:40:44 firmware power cut (parallel session's thermal-trip diagnosis); 00:42:21 kernel boot; 00:42:40 unit start (boot-time autostart, 19 s after kernel) |
| 4 | **Deploy ruled out** | `/run/current-system` → `nixos-system-evo-x2-26.11.20261014.55bfb4d` — tonight's reboot activated the Oct-14 generation; no new config went live with the crash-reboot |
| 5 | **"Unknown restarter" risk ruled out** | Current instance started at boot; the only in-boot restart (23:30) was a graceful manual-style stop; nothing in the tree periodically restarts the unit (only `dns-blocker.nix` references it) |
| 6 | **Cross-session context integrated, not duplicated** | Boot `ee085387` thermal-trip crash diagnosis, evidence-file commit blockage, and rows `docs/todo/stability.md:300-305` all belong to the parallel 00:58 session — cited, not re-derived; my rows appended after theirs |
| 7 | **Queue-surface harvest at authoring time** | 1 watch row CLOSED with measured data, 2 queued rows updated with live measurements, 3 new `[ready]` + 1 `[decision]` rows landed in `docs/todo/services.md`, 3 matching one-liners in `TODO_LIST.md`, 2 rows in `docs/todo/stability.md` — all dual-surface, no drift (ledger at end) |

## b) PARTIALLY DONE

| # | Item | Done | Missing |
| - | ---- | ---- | ------- |
| 1 | **The user-facing diagnosis itself** | Root cause + ETA + do-not-restart warning delivered within ~10 min of the question | ETA (≈01:57) was a *prediction* at session end and is still unverified at report time — close-out probe not yet run (§f.1) |
| 2 | **Cold-start measurement (the queued `--all` boot-probe row's 4 asks)** | (2) cold-start wall = **74m50s**; (1) Go-load = 15/17 eligible models loaded (`reuben`, `sd_finetuned` not exported on disk, skipped cleanly); (3) partial: mid-boot RSS 5.9G, prior-run peaks 12.8G mem + 13.1–13.3G swap | Steady-state RSS unmeasured; (4) real ensemble classify latency unmeasured — row stays open |
| 3 | **TimeoutStartSec bug** | Found, live-confirmed (systemd logs `Unknown key 'TimeoutStartSec' in section [Unit], ignoring` on every render), grep-verified at `modules/nixos/services/nsfw-classifier.nix:208`, queued with the measured re-budget (~90min, not 10min) | Fix itself NOT made (user gate: wait for instructions; deploy-gated anyway) |
| 4 | **verdicts.db cbor corruption** | Observed live (dozens of `event.decode_payload_failed` WARNs during hydration, 2780 events → 57 entries), queued for quantification | Count/classify/upstream-file not started |
| 5 | **Restart attribution** | 23:30 + 12:10 restarts proven *clean and deliberate* (graceful stops, not crashes) | WHO stopped/started them is unattributed (no journal caller trace; fish history incomplete for live terminals) — owner question §g.1 |

## c) NOT STARTED (identified this session, zero work)

1. TimeoutStartSec section move + re-budget (§b.3).
2. verdicts.db corruption quantification (§b.4).
3. Runbook "Startup timeline" section (75-min cold start is NORMAL; silent-warmup signature; never-casually-restart).
4. Caddy upstream response-timeout decision for warmup-prone vHosts.
5. Close-out probe of the ready prediction.
6. Everything on the pre-existing nsfw queue this session merely *validated as still open*: gatus-green verify on the new conditions, stale signoz-coverage comment, post-deploy smoke rows, sd_notify/Type=notify upstream ask, `/inject/filter.js` existence, runbook server-surface table, negative-tests for the two eval cases, pre-deploy model-sanity gate, the remaining post-deploy battery legs, de-dev-ification, optionify `nsfw-classifier.nix:136`.
7. Truncated-journal repair (root-required; queued `[blocked:user]`).
8. zram/swap pressure watch (queued `[watch]`).

## d) TOTALLY FUCKED UP (brutal, honest)

| # | What | Why it matters | Correction status |
| - | ---- | -------------- | ----------------- |
| 1 | **Date-less `journalctl --since "23:29:50"`** — parsed as *today's future* 23:29, returned "No entries", and I briefly concluded "the 23:30 evidence window was eaten by the truncated journal file" — a FALSE claim. My own flag bug, dressed up as an evidence gap. | A false "evidence lost" narrative nearly shipped in the diagnosis; the 23:30 stop/restart was fully logged all along. | Caught + redone with explicit dates before the second user reply; corrected narrative delivered. |
| 2 | **Read the smoking gun and scrolled past it.** The line `Unknown key 'TimeoutStartSec' in section [Unit], ignoring` (18:49:17) was IN my first journal dumps; I registered it as noise. Only during report writing did I recognize it as a live, eval-undetected config bug (the 10-min "budget" protecting nothing — and ironically the only reason 75-min boots survive). | Fix-on-sight reflex failed on a real bug sitting in my own evidence. | Queued with grep-verified module line + measured re-budget. |
| 3 | **First journal pull drowned in WARN spam** — `--since "2026-10-18"` returned ~30 identical `decode_payload_failed` lines per screen; I re-pulled with a filter one call later. Should have filtered on read #1. | Wasted cycles on a unit KNOWN (from my own repo grep) to emit repetitive warnings. | Pattern noted for §e. |
| 4 | **Two fumbled probes:** `uptime -s` (invalid flag on this box) and `busctl get-property … ExecMainStartTimestamp` (wrong interface — AGENTS.md even documents that unit properties live on `.Unit`, and I guessed a property that isn't there). `ps -o etime` answered it immediately anyway. | Two round-trips burned; both had documented/boring alternatives (`who -b`, `ps`). | Noted; live-probe set candidates listed in §f. |
| 5 | **Claimed the ETA before closing the loop.** First answer said "wait ~01:57" + "I can poll if you want" — offering the verification instead of doing it. The periodic-restarter check also came *after* the ETA was stated (verified moments later, but the order was wrong: claim-then-verify instead of verify-then-claim). | "Assert WHICH question your evidence answers" discipline says close the loop BEFORE yielding. | Backlog grew 167→245 and CPU kept climbing (progress confirmed), but the 01:57 prediction itself remains unverified at authoring — §f.1 closes it. |
| 6 | **Nothing destructive happened** — no reverts, no restarts of the warming service, no tree conflicts with the parallel session; the only writes were additive doc/queue edits. | — | — |

## e) WHAT WE SHOULD IMPROVE

1. **Close the loop before yielding.** Any prediction ("ready at 01:57") gets a probe before the session yields — even if the user didn't ask for polling. Offered verification is unfinished verification.
2. **Full timestamps in every `journalctl` window.** Bare `--since "HH:MM"` silently means *today*; on a box with mid-night sessions this fabricates "no entries" answers. Rule: date + time, always.
3. **Treat systemd warning lines as findings, not noise.** `Unknown key … ignoring` lines are inert-config bugs; a grep for `ignoring|Unknown key|Unknown section` belongs in the diagnosis checklist.
4. **Filter known-spam patterns on the FIRST read** — this unit emits dozens of identical WARNs per boot; `rg -v decode_payload_failed` from call one.
5. **Consult the queue premises BEFORE deep forensics.** The queued row "cold-start wall vs 10min" already hinted the startup is slow and budgeted; reading it first would have shortened the diagnosis by several probes (runbook + queue first, journal second).
6. **`ps -o etime,time,%cpu` is the first "is it progressing" probe** — one call answers elapsed/CPU/progression; I reached it after two systemd-side fumbles.
7. **Shared-tree etiquette held and should stay:** parallel session active all night (00:58 report, stability rows 300-305, pre-existing modified status docs from session start, one index.lock mention) — I appended-only to shared todo files, cited their findings instead of re-deriving, and flagged the overlap in §a.6.

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT (menu, not commitment — wait for instructions)

**New from this session (top = harvested; rest = candidates):**

| # | Item | Tag / status |
| - | ---- | ------------ |
| 1 | Probe `journalctl -u nsfw-classifier` for `server warmup complete` + openssl `/readyz` probe via LAN IP — verify the 01:57 prediction, then tell the user it's live (or escalate) | queued `[ready]` in spirit — do FIRST, now |
| 2 | nsfw unit: move `TimeoutStartSec` from `unitConfig` to `serviceConfig`, re-budget ~90min (10min would kill every cold boot); check the eval audit's section-awareness | **HARVESTED** — services.md + TODO_LIST |
| 3 | Quantify + classify the cbor-unreadable `verdict.created` events (dropped verdict history?) | **HARVESTED** — services.md + TODO_LIST |
| 4 | Runbook "Startup timeline" section (75-min normal, silent-warmup signature, never-casually-restart) | **HARVESTED** — services.md + TODO_LIST |
| 5 | Caddy upstream response-timeout for the nsfw vHost (504 instead of infinite spinner) | **HARVESTED** as `[decision]` — services.md (library-only) |
| 6 | Update `docs/services/nsfw-classifier.md` GPU/posture section with the measured 74m50s warmup economics (fold into #4) | candidate |
| 7 | `ss` LISTEN Recv-Q ("bound but not accepting") as a post-deploy-check §-leg for warmup-heavy services | candidate |
| 8 | Decide whether gatus's RESPONSE_TIME alert (row queued) actually fires during a 75-min warmup (client timeout ≪ warmup → should page; verify on next cold boot) | candidate (adjacent to queued row) |
| 9 | Investigate ~13G/run swap peaks + 31.7G live zram usage — acceptable-by-design or MemoryHigh tuning? | **HARVESTED** as `[watch]` — stability.md |
| 10 | Truncated journal file repair (root; 100MB unreadable span Oct 10→15) | **HARVESTED** as `[blocked:user]` — stability.md |
| 11 | Attribute the 12:10:18 / 23:30:04 nsfw stops (owner query first: §g.1) | owner-gated |
| 12 | Check whether boot `ee085387`'s 18:13 start was itself preceded by a clean shutdown (this session only saw its beginning) | candidate |
| 13 | Verify boot-mirror decode green after tonight's crash-reboot (per AGENTS discipline after ANY reboot) | candidate — post-crash hygiene |
| 14 | Commit the still-uncommitted ee085387 boot-evidence file (parallel session's blocker; §15 pre-vacuum gate blocks deploys until it lands) | already queued — stability.md:300 (NOT mine; flagged) |

**Already-queued nsfw rows this session validated as still-open and load-bearing (do next when dispatching):**

| # | Item |
| - | ---- |
| 15 | Verify gatus green on the superb-audit conditions (deploy half done; runtime unprobed) |
| 16 | Fix the stale "signoz-coverage walks Environment as a list" comment in the module |
| 17 | Runbook post-deploy smoke rows for the new alerting surfaces |
| 18 | Upstream: sd_notify/Type=notify + WATCHDOG (would make warmup state visible to systemd) + default-on `--rate-limit` |
| 19 | Verify `/inject/filter.js` actually exists on the server |
| 20 | Runbook + module comments lag the live server surface ("What it serves" table) |
| 21 | Negative-test the `full-ensemble-all-models` + `cold-start-timeout-budget` eval cases |
| 22 | Pre-deploy model-sanity gate leg in pre-deploy-check.sh |
| 23 | Remaining post-deploy battery legs (readyz green on all checks, §17 memory sweep, classify/skin/face smoke, extension re-pair, gatus) |
| 24 | Steady-state RSS + real ensemble classify latency (the open halves of the boot-probe row) |
| 25 | De-dev-ification decision (system user + ProtectHome + models out of the 0700 dev checkout) — stakes raised by the full-ensemble posture |
| 26 | Optionify `nsfw-classifier.nix:136` hardcoded `/home/lars` default |
| 27 | `/readyz` pairing-token LAN exposure decision (live-confirmed 2026-10-10) |
| 28 | Root-cause the oci-containers eval abort (same integration family, still unexplained) |

**Process/tooling candidates surfaced by this session's fumbles:**

| # | Item |
| - | ---- |
| 29 | Add `who -b` + "properties live on `.Unit`" + "date-less --since means today" to the AGENTS.md live-probe set / shell-devtools doc |
| 30 | Eval-time idea: unit-shape audit leg that rejects `[Unit]`-section keys systemd ignores (TimeoutStartSec class) — verify feasibility first |
| 31 | Consider journald rate-limit/dedup for single-unit WARN bursts (30+ identical lines per boot drown evidence) |
| 32 | Runbook convention: every slow-starting service documents its startup timeline + "normal silence" signature (nsfw would be the pattern-setter) |

*Deliberately NOT harvested:* items 1, 6-8, 11-13 (owner-gated, immediate actions, or existing-row extensions); 29-32 (process candidates needing owner buy-in); the pre-existing nsfw queue (14-28 were already tracked — this session only validated them). Harvest ledger for what DID land: see end of report.

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Were the two graceful nsfw-classifier stops yours** — Oct 17 12:10:18 (clean stop, machine rebooted ~18:13) and Oct 17 23:30:04 (clean stop + restart 9 s later)? Both were deliberate `systemctl`-style stops; I can prove the *shape* but not the *actor* (no caller trace in the journal; live-terminal fish history is incomplete by design). If they were yours, the row closes; if not, something on this box stops this unit cleanly and I need to find what.
2. **Boot posture call:** with the cold start now MEASURED at 74m50s (63 min of it silent warmup) and the box taking nightly thermal cuts that reboot it, do you want to keep `--all` as the boot posture — accepting the full filter is dead for >1h after every crash — or should I spec a serve-fast/warm-lazy scheme upstream (fast model serves immediately, ensemble loads behind it, ready flips when warm)? The 2026-10-11 "full server to test everything" call predates this measurement.
3. **Swap policy:** the ensemble rides ~13.1–13.3G of swap per run (zram) and system zram sits at 31.7G/65G used. Accept as designed (MemoryHigh 12G throttles, zram absorbs, memory.events stay clean) — or should MemoryHigh come down so the ensemble throttles CPU instead of swapping (freeze-family-safer, slower warmup)?

---

## Harvest ledger (self-harvest discipline, at authoring time)

| Change | Surface(s) |
| ------ | ---------- |
| CLOSED the `cold-boot model load vs DefaultTimeoutStartSec` watch with the live measurement (budget inert + 74m50s) | `docs/todo/services.md` (row 279) |
| UPDATE: live boots partially answer the `--all` boot-probe row (2 answered, 3 partial, 4 open) | `docs/todo/services.md` (row 282) + `TODO_LIST.md` (row 1266) |
| UPDATE: one post-deploy-battery leg delivered unplanned (cold-boot wall measured) | `docs/todo/services.md` (row 285) |
| NEW `[ready]`: TimeoutStartSec inert + re-budget | `docs/todo/services.md` + `TODO_LIST.md` |
| NEW `[ready]`: cbor corruption quantification | `docs/todo/services.md` + `TODO_LIST.md` |
| NEW `[ready]`: runbook Startup-timeline section | `docs/todo/services.md` + `TODO_LIST.md` |
| NEW `[decision]`: Caddy upstream response timeout | `docs/todo/services.md` only (library-only by queue rules) |
| NEW `[watch]`: zram swap pressure (31.7G live; ~13G/run service peaks) | `docs/todo/stability.md` only |
| NEW `[blocked:user]`: truncated journal file repair (root) | `docs/todo/stability.md` only |

**Shared-tree note:** a parallel session is active on this tree (authored `docs/status/2026-10-18_00-58_boot-ee085387-thermal-trip-crash-diagnosis-selfreview.md` + `docs/todo/stability.md:300-305` during this window; session-start git status also carried 3 modified status docs from 2026-09 I did not author and did not touch). My edits are strictly additive to shared todo files and this report; their rows were not modified.

*Format note: `.md` per the prompt's explicit path demand (skill default is HTML; the dispatch-shaped `.md` path convention applies — not propagated anywhere).*
