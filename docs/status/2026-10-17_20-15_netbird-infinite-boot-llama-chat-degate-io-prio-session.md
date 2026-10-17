# NetBird Infinite Boot + llama-chat De-Gate + IO-Priority Opinion — Session Report

**Date:** 2026-10-17 20:15 CEST (session arc ~18:55 → 20:15)
**Turns:** (1) IO-priority opinion (boot / shortly-after-boot / GB-scale model loads); (2) live "infinite boot" incident (`systemd-analyze plot` refused); (3) "is llama-chat pretending to boot forever?"; (4) owner ruling — model load is readiness, not boot → de-gate executed; (5) owner catch — `network-online.target` cargo cult; (6) this report.
**Parallel sessions:** the deploy-pipeline session (report `2026-10-17_19-44_deploy-pipeline-optimization-netbird-outage-incident.md` — same incident from the deploy side: pbx management-plane DNS-race death → their 19:34 deploy system-925) and at least one more deploy ~20:10 (`rm56zlza`). Coordination worked as designed (their §a.10/§d note one mtime-race rejection, one duplicate avoided).
**Tree:** pinned `d7b67d0a` (clean) at the netbird edit; HEAD `fcc2cc5b` (clean) at 20:11 — the daemon swept everything; both my unit fixes are DEPLOYED (unit-file-verified, evidence below).

---

## TL;DR

The "infinite boot" was `netbird-evox2-login.service`: an unbounded nixpkgs poll loop (`until netbird status | grep -q ': Connected\|NeedsLogin'; sleep 1` with `2>&1 || :` swallowing every failure) in a `Type=oneshot` (default `TimeoutStartSec=infinity`) sitting in multi-user.target's wait set — holding the boot transaction open 55+ min with the desktop fully up. Fixed in-tree (After=multi-user + 2min timeout + unit-level onFailure), deployed within the hour. The owner's follow-up rulings executed the llama-chat de-gate (After=multi-user.target + BE/5 + network-online dropped) — also deployed. §d is honest: I cargo-culted `network-online` through my own de-gating edit (owner caught it), botched one edit placement, mangled one probe with an `rg -r` flag, false-positived two units in my journal diff, and asserted a FinishTimestamp attribution the parallel session's evidence contradicts.

---

## Evidence base (all probes this session, live)

| Probe | Result |
|---|---|
| `busctl … Manager ListJobs` (~19:05) | 4 jobs: netbird-evox2-login **start/running** (job 531, since 18:13:58); boot-metrics-emit, multi-user.target, graphical.target all **waiting** |
| Journal Starting-without-Started diff | 3 candidates: netbird-evox2-login (true), linger-users + browser-history-agent-token-provision (**false positives** — oneshots log "Finished", both fine) |
| Login script source (store) | The unguarded `until … sleep 1` + `get_status() { … 2>&1 \|\| :; }` — errors invisible |
| netbird-evox2 daemon journal | management gRPC setup lines cycling every 20-30s all boot — never Connected (env cause: pbx, per parallel report) |
| Wrapper store path `a1awc19d…` | Readable 19:05 → **ENOENT 19:12** (mid concurrent build, 182 nix procs) → still ENOENT 20:11 — while `nix path-info -r` lists it in BOTH booted+current closures |
| Generations | booted `zmnzbs3f` ≠ current `sgjss8fz` (19:07) → `rm56zlza` (20:11); deploys 19:34 (system-925) + ~20:10 |
| Parked converger | `sudo systemctl restart netbird-evox2-login` PIDs alive since ~18:50 (the 18:43 deploy's converger) |
| `FinishTimestampMonotonic` (19:52) | 5371299559 µs ≈ 89.5 min ≈ 19:43:20 — transaction eventually closed; **closer attribution uncertain** (§b.2) |
| llama-chat journal | Starting 18:13:56 → **Started 18:24:45** (10m49s, bounded, completed) |
| `/run/current-system/etc/systemd/system/netbird-evox2-login.service` (20:12) | `After=netbird-evox2.service multi-user.target`, unit-level `OnFailure=notify-failure@%n.service`, `TimeoutStartSec=2min` — **my fix LIVE** |
| `/run/current-system/etc/systemd/system/llama-chat.service` (20:12) | `After=multi-user.target`, `IOSchedulingClass=best-effort` + `IOSchedulingPriority=5` — **my fix LIVE** |
| `scripts/check-todo-system.sh` | "OK: TODO queue/library structure clean" (the 130 UNHARVESTED warnings are pre-existing global debt; this report self-harvests) |

---

## a) FULLY DONE

1. **IO-priority opinion delivered (turn 1, exploration mode, zero uninvited implementation)** — grounded in stability.md freeze history + live ioTier census: BFQ prio = who waits, never fewer bytes; model-load speed is a streaming problem; boot/recovery window = serialization/gates/deferral. Two docs lessons reinforced (idle-starvation borg precedent; io.latency↔BFQ exclusivity).
2. **Infinite-boot diagnosis, live, in one probe round** — `busctl ListJobs` named the holder instantly where `blame` is structurally blind (completed units only). Full root-cause chain: unguarded poll + swallowed errors + oneshot-infinite-timeout + wait-set membership; environmental trigger (pbx management death) root-caused by the parallel session; store-GC wrinkle observed and queued (§b.1).
3. **netbird.nix fix: three bounds** — `after = ["multi-user.target"]` (off the target's wait set), `TimeoutStartSec = "2min"` (wedged login → loud failure), unit-level `onFailure` (notify-failure@). Eval-verified; **deployed** (system-925 + rm56zlza); row closed by the parallel session with live unit-file evidence (services.md:589).
4. **Found + documented the `serviceConfig.OnFailure` [Service]-section no-op class** — verified against the live visionreviewd unit (renders under [Service], systemd ignores it); netbird wired unit-level; visionreviewd latent bug queued [ready].
5. **llama-chat de-gate executed (owner ruling = the answer to the 10:44 report's §g.1)** — `After=multi-user.target` + `ioTier.heavyDB` (BE/5) + **network-online.target removed** (owner catch); start contract unchanged (started == /health 200; ensure-timer converges); gatus precondition verified BEFORE the move (no check probes llama-chat directly). Eval-green; **deployed** (unit file 20:12).
6. **Row 8 closed on BOTH surfaces** (TODO_LIST stability one-liner + stability.md full row, with mechanism note: After= pattern instead of the row's OnBootSec-timer shape — same outcome, unit keeps multi-user.wants deploy coverage). Row 244 (transaction-open) updated with the now-proven diagnosis recipe + second live instance.
7. **Harvest, both surfaces, same session**: net-vpn.md runbook bullet (incident + remedy + recipe); services.md rows (audit class-5 [ready], visionreviewd fix [ready], netbird deploy row — closed by parallel); network-online sweep [ready]; TODO_LIST one-liners for each. **AGENTS.md probe-set entry: `busctl ListJobs`** (+ the `.Unit`-not-`.Service` ActiveState gotcha) — the durable memory of this session's method.
8. **Load-window opinion cluster harvested as [ready] rows** (§f.C) — pre-warm, PSI gates, serialization, hot-tier move, fastflowlm waiting-gate, hermes-perms-heal audit, store-GC anomaly, FinishTimestamp gap.

## b) PARTIALLY DONE

1. **Store-GC anomaly UNRESOLVED** — wrapper path deleted from disk mid-build while listed in both closures' `path-info`; running daemon + login script execute from the deleted inode; daemon restart = broken until a deploy rebuilds the closure. Row queued; no confirmation the next build re-creates it (deterministic wrapper → should; unproven).
2. **FinishTimestamp closer attribution UNCERTAIN** — I told the owner "written when you stopped netbird"; the parallel report has the login Finished 19:19:18 via their pbx fix (deploy self-unblocked then), but monotonic 5371s ≈ 19:43:20 leaves a 24-min gap with no named closer. Forensic row queued (§d.5 owns the overclaim).
3. **Post-deploy observational legs pending a reboot/outage**: next-boot userspace ≤~40s with llama-chat Starting AFTER multi-user; the wedged-login 2min-timeout + notify-failure path (needs a real outage); anchor check for the ~20:10 rm56zlza deploy (not verified by me — the parallel session verified 925).
4. **CHANGELOG entries for today's [x] closes not written** (row 158 + stability.md:243 + services.md:589) — prune-pass convention covers it, noted for the next docs pass.
5. **Gatus expectation not yet annotated**: this boot's userspace reads ~89.5 min → the "Boot Userspace Regression" check is RED by design until the next good boot (its own alert text says so). Owner should expect it; no doc/config touched.

## c) NOT STARTED

1. **systemd-shape-audit class 5 itself** (the eval gate + negative test) — row queued, not built. Same for the visionreviewd one-line fix and the network-online sweep (rows only).
2. **Pre-existing rows advanced by context but not executed**: family audit (stability.md:245), compsize battery (:246), btrbk definition-site tier verify, row 244's gauge.
3. **user.slice IO tiering scoping** — morning §g.3, still an open owner question; not scoped, not queued.
4. **Load-window execution** (pre-warm/PSI/serialize/hot-tier) — rows fresh, zero code.

## d) TOTALLY FUCKED UP

1. **I cargo-culted `network-online.target` through my own de-gating edit.** The session's central theme was scrutinizing boot gating; I verified the GATUS precondition but carried the existing wants/after network-online into the new ordering without questioning it — and the OWNER caught it one turn later. A de-gating edit must audit the ENTIRE dependency set (deps, conditions, gates), not append to it.
2. **First netbird.nix edit was botched twice-over** — inserted the fix block at the top of `config = mkIf` (creating a duplicate attrpath with the existing `wantedBy` line) AND referenced `onFailure` before adding it to the inherit. Two fix-up rounds. Root cause: edited before fully locating the existing definition site.
3. **`rg -r` mangled a probe and I classified on the mangled output** — `-r` is rg's REPLACE flag; the consumer scan printed rewritten text; I inferred inboxclean/ai-meter consumers partly from it instead of re-running clean. (Conclusions happened to hold; evidence path was invalid.)
4. **Journal-diff methodology blind to oneshots** — Type=oneshot logs "Finished", not "Started"; linger-users + browser-history-agent-token-provision came out as false "stuck" candidates, and I dropped them mid-incident without follow-up (both verified normal at 20:11: periodic + already-provisioned no-ops). Diff candidates must be validated against unit Type before reporting.
5. **Attribution overclaim to the owner** — "FinishTimestamp was only written when you stopped netbird" stated as fact; the parallel session's 19:19:18 self-heal evidence contradicts it and I never verified the actual closer. This is the house's own "assert WHICH evidence answers WHICH question" rule, violated in the direction of a confident narrative.
6. **Content-pin discipline decayed** — pinned once (d7b67d0a) before the netbird edit, never re-pinned before the net-vpn/TODO/stability/AGENTS edits while HEAD moved to fcc2cc5b. All writes landed clean (mtime-race protection + luck).

## e) WHAT WE SHOULD IMPROVE

1. **De-gating edits audit the whole gate set** — when moving a unit off the boot path, re-derive every dependency it carries (wants/after/conditions), not just the one being fixed. (d.1's rule-form.)
2. **Mangled output = invalid evidence** — re-run the probe clean before classifying; flag-shape anomalies (text that looks replaced) are a stop signal, not a curiosity.
3. **Oneshot-aware forensics** — the Starting/Started diff needs a Finished branch for oneshots; better: validate candidates against `Type=` before reporting them as stuck.
4. **Attribution claims need the closing evidence** — especially "X happened because you did Y" statements to the owner; a consistent story is not a verified one.
5. **Harvest opinion outputs at opinion time** — the morning session's §d.3 lesson, repeated here: the load-window cluster lived as prose for four turns before report-time harvest.
6. **Re-pin before every write batch** in multi-writer windows — the rule exists; this session is a reminder it must be per-batch, not per-session.

## f) Up to 50 things to get done next

**A. Deploy/verify (this session's fixes)**
1. Next-reboot battery: userspace ≤~40s calm, llama-chat Starting AFTER multi-user active, netbird login post-boot ordering — pairs with the standing calm-boot re-measure (§g.2 of the 10:44 report)
2. Wedged-login observational leg: a real netbird outage must now fail at 2min + notify-failure (deploy row's open half)
3. Anchor check for the ~20:10 `rm56zlza` deploy (I verified system-925 via the parallel report only)
4. Annotate/expect the gatus "Boot Userspace Regression" RED for this 89.5-min-userspace boot (clears on next good boot by design)

**B. Eval gates + one-liners (rows queued this session)**
5. systemd-shape-audit class 5: boot-blocking oneshots need finite TimeoutStartSec (+ allowlist + negative-test-lints selftest)
6. visionreviewd OnFailure [Unit]-section fix
7. network-online sweep across ~20 modules (loopback-only binders drop it; keep on fetch/outbound/LAN units)
8. CHANGELOG entries for today's three [x] closes

**C. Load-window cluster (rows harvested this session)**
9. llama-chat streaming pre-warm ExecStartPre (fault-paging → sequential stream; measure blame delta)
10. PSI entry gates for cold loads (refuse-style for boot units, waiting-style for socket-activated flm/vlm)
11. Serialize concurrent cold loads (heavy-job slot / After= chain)
12. Active GGUF set → Samsung hot-tier +C subvol (space check first)
13. fastflowlm/llama-vlm first-request cold-load gate design
14. hermes-perms-heal 7m52s boot-window audit (trigger cadence, tier, defer?)

**D. Forensics (rows harvested this session)**
15. Store-GC anomaly: wrapper deleted-while-in-closures; confirm rebuild-on-next-build; daemon-restart landmine until then
16. FinishTimestamp 19:19→19:43 gap: journal the closer
17. (from parallel report, pbx side is theirs) — nothing SystemNix-side pending beyond rows 2/10

**E. Pre-existing rows advanced by this session's context**
18. Family audit multi-user >30s starts (stability.md:245 — hermes-perms-heal + btrbk are the next suspects)
19. compsize boot-window battery (stability.md:246)
20. btrbk tier at its definition site (services.md row)
21. transaction_open_seconds_past_graphical gauge (stability.md:244, recipe now proven)
22. ioTier coverage eval-gate (morning row 17)

**F. Carried owner questions / larger moves**
23. user.slice IO tiering scoping (morning §g.3 — question 2 below)
24. Quiet-window deliberate reboot (question 3 below — verifies everything in A.1)
25. Crush session DBs off QLC root (storage row — the structural user.slice fix)

(25 real items; no filler.)

## g) Three questions I cannot figure out myself

1. **Load-window work dispatch priority** — de-gate + BE/5 is live; the remaining cluster (pre-warm, PSI gates, serialization, hot-tier move) is queued [ready]. Dispatch now, or is the current posture enough until the next calm-boot measurement tells us the real load time?
2. **user.slice IO policy scope** (morning §g.3, still open): the storm's top stalled cgroups are your own user manager + session scopes. Tier that half (HM defaults + dedicated agent slice), or is user.slice your interactive territory that system policy must not touch?
3. **Deliberate quiet-window reboot soon?** One planned reboot verifies BOTH fixes live (userspace floor, llama-chat post-boot ordering, netbird post-boot start), takes the calm-boot re-measure the 10:44 report still owes, and clears the gatus boot-regression RED — or keep waiting for an organic boot?

---

*Probes this window: busctl ListJobs/get-property, journalctl (unit timelines, Starting/Finished diffs, sudo/parked-converger forensics), nix path-info closure checks, stat/ls on store paths, /proc pressure + uptime + PID starttime, pgrep (nix build census, netbird processes), readlink on booted/current/profile, evals (unit attrs ×5, full toplevel ×3), check-todo-system.sh, unit-file reads from /run/current-system. Writes: netbird.nix, llama-chat.nix, AGENTS.md (busctl probe entry), net-vpn.md, TODO_LIST.md, docs/todo/services.md, docs/todo/stability.md, this report. All landed clean; tree clean at fcc2cc5b.*
