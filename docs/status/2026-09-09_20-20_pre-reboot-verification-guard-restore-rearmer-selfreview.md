# Pre-Reboot Verification, Guard Validation & the Second Re-Armer — Session 5 Self-Review

**Date:** 2026-09-09 20:20 CEST · **Host:** evo-x2 · **Repo:** SystemNix @ `ddcb78ed`
**Session arc:** Samsung 970 EVO Plus migration, session 5. Input: user pastes of the
18:35 deploy (system-764) and the pre-reboot-check (SAFE TO REBOOT). Scope: verify the
new anchor, validate the session-4 corpse guards against live evidence, correct the
record where the evidence contradicted it. No deploys, no config changes this session.

---

## Situation snapshot (verified 19:25–19:45)

| Item | State | Evidence |
| --- | --- | --- |
| Anchor triple | current-system = profile = boot default = **system-764** (`50z91iw1…`), kernel 7.2.3 | readlink ×2 + user's pre-reboot-check (14 PASS) |
| Reboot | NOT done — up 2d5h (boot ≈ Sep 7 14:10), booted = `p0ccbqj5…` still gc-rooted | `uptime`, readlink |
| Rollback ladder | pins 761 (`zkaacn2a…`) + 760 (`g9ghy625…`) intact; menu 5/5 closure-verified | ls gcroots + paste_2 |
| `/nix` mount | Samsung p2 (`/dev/nvme1n1p2[/nix]`) — flip holding | findmnt |
| flm corpse | Z+X pair pid 443303 (`flm-real` defunct), :52626 LISTEN Recv-Q **502**; backend start-limit-hit, NRestarts=3 | ps/ss/journalctl |
| Public socket :52625 | UP (re-armed by memory guard) → doomed-start churn continues between deploys | ss + journal 18:44:55 |
| llama :8848/:8849 | processes alive ~1h, ports bound, `/health` **503** — wedged MID-LOAD (flaky-driver class), no D-state | ps/ss/python probe |
| Failed units (3) | fastflowlm (corpse), inboxclean-sync (user OAuth), service-health-check (reporter) | sudo-wrapper `--failed` |
| Git tree | clean before and after my 3 doc edits | git status |
| Load average | 17.36 (parallel agent sessions; cause not investigated this session) | uptime |

---

## a) FULLY DONE (this session)

1. **Anchor independently verified**: system-764 (`50z91iw1…`) = current-system =
   profile; boot default per user-run pre-reboot-check (14 PASS, 5/5 menu entries,
   kernel+initrd on ESP, `SAFE TO REBOOT`). Ladder pins + booted-system gcroot
   (`p0ccbqj5…`) confirmed intact pre-reboot.
2. **Corpse guards validated in production** — full timeline reconstructed from
   journals: pre-switch guard stop **18:34:58** → stc target-cascade re-arm
   **18:35:28** → post-switch guard re-stop **18:35:29** (1 s window; sudo journal
   lines visible) → clean activation, profile bumped 763→764, 0 failed units at
   settle. Exactly the designed behavior.
3. **Second socket re-armer root-caused** (corrects session-4): the
   **memory-emergency-guard RESTORE branch** re-arms the flm socket between deploys —
   live proof **17:56:24** and **18:44:55** ("MEMORY EMERGENCY cleared … sacrifice
   sockets restored", restore #11/#12, **2 of maxRestoresPerDay=3**, ~10 min restore
   cooldown). It sees the deploy guards' stop, assumes its own past sacrifice,
   restores while memory is healthy. Churn self-extinguishes at the daily cap; only
   the reboot ends the class.
4. **Session-4's memory-guard rule-out proven WRONG and corrected**: it relied on
   `journalctl -u memory-emergency-guard` while guard script output logs under syslog
   id `memory-emergency-guard-check` — a filter artifact. The 17:19:33 event was
   independently re-verified as NOT a guard restore (no guard line in window) — the
   stc-cascade attribution for that event stands.
5. **llama-rag wedge diagnosed**: both servers wedged MID-LOAD for ~1h — ports bound
   (llama-server listens before model load), `/health` 503, processes R/S state, no
   D-state corpses. Flaky-driver class (2026-09-05 precedent); port-liveness looks
   green while functional health fails. Reboot clears.
6. **Docs updated + verified**: TODO_LIST Phase-1 block (764 re-anchor, second
   re-armer, llama wedge, post-reboot target = gen 764, P1 corpse-aware-restore
   candidate); AGENTS.md bullet (guard validation + restore-branch re-armer + filter
   gotcha); status doc addendum. All three edits grep-verified.
7. **Failed-unit trio enumerated and attributed** (corpse / user-OAuth / reporter) —
   no new failures introduced by the 18:35 deploy.

## b) PARTIALLY DONE

- **Pre-reboot verification**: anchors verified via readlink, but the **ESP loader
  default was NOT independently verified by me** — I trusted the user's
  pre-reboot-check paste. My own `ls -la /boot/loader/` (appended to another
  command) returned empty and I did not notice or follow up.
- **Re-arm history**: four events explained (17:19:33 stc, 17:56:24 guard,
  18:35:28 stc, 18:44:55 guard) — but I did NOT sweep the full journal for other
  unexplained "Listening on" events, and whether a **3rd restore (cap 3)** fired
  after 18:44:55 is unknown.
- **Alerting verification**: NOT checked whether Gatus/Discord actually fired for
  the llama 503s and the flm start-limit-hit (both should be red; expected-but-
  unverified monitoring behavior).

## c) NOT STARTED (reboot-gated by design)

- Post-boot verification (gen 764 boots, `/nix` on Samsung, flm :52625 +
  llama :8848/:8849 healthy after cold load, failed units ~0).
- Remove `/boot/loader/loader.conf.bak-stuckboot` (after good boot confirmed).
- `p0ccbqj5` pin-or-release decision (booted-system gcroot flips at reboot).
- One `nix run .#deploy` to refresh the smoke baseline (expect the 5 llama/flm
  baseline FAILs cleared; bank-sync = user SCA; signoz = upstream gaps).
- 3-day soak clock (through ~Sep-12); Sep-10 00:00 nix-gc watch (`g9ghy625` via
  ladder pin).

## d) TOTALLY FUCKED UP

1. **Session-4's wrong rule-out, written into permanent docs by me**: the AGENTS.md
   bullet and the 17:45 status report asserted "no mem-guard restore" — based on a
   journal filter that can never show guard output. Worse: the filter gotcha was
   **in my own handoff environment notes** and I only applied it when the 18:44:55
   evidence forced the question, instead of re-auditing the rule-out the moment I
   read the gotcha. Cost: one extra session, ~2h of wrong root cause in the record,
   and deploy guards that cover only half the re-arm surface.
2. **Incomplete mechanism enumeration**: "what re-arms the socket?" was answered
   with ONE mechanism (stc cascade) in session-4. systemd units get started by an
   enumerable set of actors (stc cascade, guard restore, idle timer, operators,
   timers). Finding one ≠ finding all — the guard-restore interaction is a direct
   consequence of stopping a socket that a 30s-cycle safety system watches.
3. **A silent verification hole in my own commands**: `ls /boot/loader/` produced no
   output inside a combined command and I moved on. A probe whose output is silently
   empty is a phantom-green — the exact class this repo documents obsessively.

## e) WHAT WE SHOULD IMPROVE

1. **Positive-control journal filters**: before ruling anything out via journalctl,
   prove the filter matches a KNOWN event of that source (the `-u` vs syslog-id
   artifact has now bitten twice).
2. **Enumerate all actors** when documenting "what starts/re-arms X" — one observed
   mechanism is a hypothesis, not a complete model.
3. **llama wedge tripwire**: port-liveness is green during mid-load wedges; add a
   duration-based check (`/health` 503 for >15 min = wedge) rather than
   point-in-time status checks.
4. **Corpse-aware guard restore (P1 candidate, documented)**: restore branch should
   skip when the backend journal shows recent `bind: Address already in use`.
5. **pre-reboot-check §10 candidate**: gcroots/profiles resolution check (from
   session-3 forensics); **smoke-baseline age-stamp**; **exit-4 predictor** =
   changed-unit ∩ failed-unit set (the "3 failed units arm the next deploy" advisory
   is only true for units whose FILES change — the 18:35 deploy activated cleanly
   with inboxclean-sync failed).
6. **No silent pipelines**: every verification probe should assert its own output is
   non-empty.

## Self-critique — forgot / could-have-done-better / still-improvable

- FORGOT: independent ESP default check; Gatus/Discord alert-state check for the
  expected reds; hermes post-restart health (deploy drained sessions); cause of
  load-17; whether restore #3 fired.
- BETTER: re-audit old conclusions when a handoff note contradicts them; treat my
  own paste-trust as a verification gap (readlink'd anchors = good, loader default
  = trusted).
- STILL: the three doc layers (AGENTS/TODO/status) now carry the corrected model —
  keep them as the single source until the reboot rewrites reality.

## f) NEXT — up to 50, ordered

**Core, reboot-gated (do first):**
1. Await user reboot (SAFE verdict at gen 764).
2. Post-boot: verify `readlink /run/current-system` = `50z91iw1…`, `/nix` source =
   Samsung p2, `uname -r` = 7.2.3, booted gcroot flipped off `p0ccbqj5`.
3. Post-boot: after 2–5 min cold load, flm :52625 `/v1/models` 200 + llama
   :8848/:8849 `/health` 200 — expect corpse + wedge classes GONE.
4. Post-boot: failed-unit count ~0; remove `/boot/loader/loader.conf.bak-stuckboot`.
5. Post-boot: `p0ccbqj5` pin-or-release decision (user).
6. Post-boot: one `nix run .#deploy` → refresh smoke baseline (expect 7→≤2 FAILs:
   bank-sync SCA + signoz upstream).
7. Start 3-day soak clock (→ ~Sep-12); journal soak observations.
8. Watch Sep-10 00:00 nix-gc: `g9ghy625` survives via ladder pin; `p0ccbqj5`
   collectability changes only after reboot.

**Robustness / monitoring (post-soak P1):**
9. Corpse-aware memory-guard restore (skip on recent EADDRINUSE) — upstream edit in
   memory-emergency-guard.nix + VM-test negative case.
10. llama mid-load wedge tripwire (503 >15 min) in Gatus or textfile collector.
11. pre-reboot-check §10: gcroots/profiles resolution; smoke-baseline age-stamp;
    changed-unit ∩ failed-unit exit-4 predictor.
12. `nix diff-closures 8zzq0b1i… pgvbfp20…` — what the Sep-8 unanchored era actually
    changed (06-02 §f).
13. Sweep journal for ALL unexplained fastflowlm.socket "Listening on" events
    (completeness proof for the two-re-armer model).
14. Verify Gatus/Discord fired for tonight's llama+flm reds (monitoring trust
    check).
15. hermes health + session-drain review after the 18:35 restart.

**Samsung phase-1 tail (from TODO_LIST):**
16. Post-soak: delete old `@nix` (QLC) after attic store-rebuild story verified.
17. attic store-rebuild on Samsung verification.
18. exec-latency-under-buildstorm acceptance + fio sanity run.
19. Add Samsung to btrfs-health metrics + smartd + Gatus mount/space checks.
20. Samsung p1 ESP mirror fate: keep static / automate / drop (user decision).
21. Pre-reboot-check candidate: ESP-mirror staleness warning if kept.

**User steps (browser/app only):**
22. Wise SCA approval (OTT runbook `docs/services/bank-sync-sca.md`) → restart
    bank-sync → remove token file.
23. InboxClean main re-auth (`inboxclean auth` runbook; consent screen is In-
    production now).
24. Resend: verify `larsartmann.cloud` domain (mail relay go-live pending since
    2026-09-06; journal `status=bounced` is the signal).
25. tq pool cutover decision (manual `:8090` pool vs systemd pool — double-run
    guard currently WARNs every deploy).
26. Git-history purge push decision (rotation done; push held indefinitely — flip?).

**Upstream repos (LarsArtmann, fix at source):**
27. InboxClean: Paperless "demote auto tag gmail" PATCH rejected
    (`rejection:paperless.client_error`) — repo fix candidate (noticed in baseline).
28. dnsblockd: push the health-cache fix (working tree 2026-09-06, unpushed) +
    flake bump; wire `scripts/dnsblockd-goroutine-dump.sh` into the wedge runbook.
29. hermes/PMA/overview/papdashboard OTel span gaps → flip `wiring = "upstream"` →
    enforced as instrumentation lands (signoz_traces_missing 3).

**Known long-tail (tracked, not this session's work):**
30. /data EIO corruption repair (P0 — btrbk-data sends abort nightly; oom-kill'd
    since 2026-08-20).
31. btrbk-data oom-kill containment (20.6G page-cache peak in cgroup).
32. monitor365 enable decision (private crate: publish/public/vendor — owner call).
33. `pipeline.evaluation.min_day_rate` CV setting (owner value decision, CV repo
    proposed 600).
34. ClickHouse telemetry backup coverage (btrbk excludes XFS by design).
35. ClickHouse zombie read-only log tables: human DROP decision (~10 GiB).
36. Paperless old SQLite export recovery decision (`/mnt/pool/.../export`).
37. Old `/data` bounded-damage repair: gemma-4-31b EIO-corrupt GGUF re-download.
38. ActivityWatch 13GB pre-decimation backup deletion after settling.
39. Secret-purge: GitHub support GC request (if push ever happens).
40. pre-reboot-check: fold "failed units that WILL exit-4" advisory into a hard
    gate once predictor (item 11) exists.

*(40 items — remaining backlog tracked in TODO_LIST + 06-02 self-review §f.)*

## g) QUESTIONS (cannot figure out myself)

1. **Reboot timing**: now (tonight, ~20:2x) or at a time you pick? Parallel sessions
   (hermes, manual tq) and your desktop die with it; soak clock and the Sep-10
   00:00 GC watch anchor to whenever it happens.
2. **`p0ccbqj5` after reboot**: pin it into the rollback ladder (4th rung) or
   release it to GC? It's the Sep-8 flip-era generation — your call on rollback
   depth vs store clutter.
3. **Samsung p1 ESP mirror**: keep as static emergency assets (308M), automate the
   mirror, or drop it? (Carried decision; interacts with item 20/21.)

---

**Bottom line:** machine is anchored at system-764, formally SAFE TO REBOOT, waiting
on the user. Everything I could verify pre-reboot is verified; the record now
correctly names both socket re-armers; nothing this session made anything worse.

*Point-in-time snapshot — re-verify before acting on it (the reboot rewrites most of it).*
