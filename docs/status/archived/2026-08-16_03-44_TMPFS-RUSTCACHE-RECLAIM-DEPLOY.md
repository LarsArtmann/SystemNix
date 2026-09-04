# TMPFS Reclaim + `/rust-cache` Retirement — Session Status

**Date:** 2026-08-16 03:44 CEST
**Session scope:** /tmp cleanup decision → `/rust-cache` inspection → wipe + mount removal → deploy → verification → docs. Sibling sessions were concurrently active (alert-spam fixes `66e78231` landed before my deploy; new uncommitted edits to `gatus-config.nix`, `pre-deploy-check.sh`, `CHANGELOG.md` appeared mid-session — not mine, untouched).
**Report covers this session only.** Carried items from `2026-08-16_03-08_GO-BUILD-CASCADE-FIX-DEPLOY-RECOVERY.md` are referenced, not re-audited.

---

## a) FULLY DONE

1. **`/tmp` analyzed + cleaned: 42G → 406M (tmpfs, RAM-backed).** Swept open-file check (`lsof +D`) first — active desktop processes (niri, helium, zellij, electron, Xwayland) held only small runtime files, untouched. Deleted: `/tmp/bigtest` (40G benchmark dataset, no open handles, regenerable), session benchmark scratch (`tw-sim`, `sbx{,2,3}`, `bh-tagtest`, `tc`, `fresh-consumer`, `lint-repro`, `bench1.txt`, `BenchmarkStartup…`), `signoz-src` + tarball, 9-month-old `nvme-cli-2.16`, stale `nix-shell.*` dirs. Kept `node-compile-cache`, `bunx-*` (actively reused, tiny). **~41G of RAM/zram freed.** Used `rm` deliberately — trashing tmpfs contents would _copy_ 40G onto the 92%-full NVMe (same documented exception as buildcache GC).
2. **`/rust-cache` contents inspected and answered:** exactly one thing lived on the entire 98G partition — a stale 32G `monitor365` debug `target/`. Migration copy verified present and complete at `/mnt/buildcache/rust/monitor365` (35G, same 10 top-level entries, Aug 14). Project symlink already points there; sccache additionally covers rebuilds.
3. **Contents wiped:** 32G → empty (partition now 2.1M used). First `rm -rf` of the dir itself failed (`Permission denied` — root-owned parent); emptied contents instead (owned by `lars`).
4. **Mount removed from Nix:** `fileSystems."/rust-cache"` deleted from `platforms/nixos/hardware/hardware-configuration.nix` with an explanatory comment pointing at the TODO_LIST remainder. `nix flake check --no-build` passed. Deployed (`nix run .#deploy`). **`findmnt /rust-cache` confirms unmounted** — automount gone.
5. **Smoke verification driven to green:** initial post-deploy 5 FAIL → final **39 PASS / 4 FAIL / 9 SKIP / 1 WARN**. All 4 remaining FAILs are the documented permanent monitor365 noise (services deliberately disabled 2026-08-12, TODO_LIST line 51). The browser-history FAIL was root-caused as a timing artifact and resolved (see d-4/e-1).
6. **pocket-id SQLITE_BUSY FAIL (carried item #2): implicitly CLEARED** — absent from the FAIL list in all three post-deploy-check runs this session (03:26, 03:37, 03:41+).
7. **Docs updated:** TODO_LIST item 47 split into done (wipe + mount removal) vs remaining (partition surgery + subvolume automounts); AGENTS.md updated in two places (subvolume-layout paragraph now describes buildcache symlinks + sccache; `/rust-cache` retirement entry). `nix fmt` run at close: 0 changes needed.

---

## b) PARTIALLY DONE

1. **`/rust-cache` partition reclaim** — mount gone, contents gone, but the **98G partition still exists** (space partitioned off from `/`). Actual reclamation needs manual `parted` surgery + adjacent-BTRFS grow + `btrfs filesystem resize`. A root-owned empty `/rust-cache` mountpoint dir (4K, cosmetic) remains on `/` — needs sudo to remove.
2. **Disk crisis relief: currently ZERO on `/`.** `/rust-cache` was a separate partition — wiping it freed nothing on root. **`/` is still 92% (648G/723G, 57G free)** — verified at session end. The real levers (partition grow +98G, redundant subvolume automount reclaim, TODO 46 Docker-to-SSD2) are all still ahead.
3. **Redundant `@cache-home`/`@go`/`@npm`/`@cargo` automount removal** — same TODO_LIST batch, explicitly out of this session's scope. Repo-wide grep confirmed no other live references to `rust-cache` beyond comments (snapshots.nix:37, buildcache.nix:98 — both comments; btrbk has no reference).

---

## c) NOT STARTED (in scope, deliberately deferred or carried)

1. `go test ./...` on the 3 bumped repos (browser-history, go-cqrs-lite, file-and-image-renamer) — carried F3 gap from previous session.
2. Verification that sibling `66e78231` (alert-spam fixes C1–C5) behaves correctly live — it shipped to production _by my deploy_ but is the sibling's work (see d-4).
3. Whether Gatus fired Discord alerts during browser-history's ~9 min deploy downtime (03:26→03:39, double restart × ~4.5 min bind delay) — unverified; ironic given the alert-spam fixes just landed.
4. Root-cause of browser-history's ~4.5-min pre-bind CPU burn (observed twice this session; what runs between "OAuth2 providers configured" and "server starting" is unexamined).
5. Which WARN remained in the final post-deploy-check run (I/O pressure vs quickshell journal) — never identified.
6. HARVEST of the previous report's section (f) into TODO_LIST/ROADMAP — still awaiting instruction.

---

## d) TOTALLY FUCKED UP (honest accounting)

1. **Predictable `rm` failure:** `ls -la /rust-cache/` in the SAME prior tool call showed the root-owned parent (`drwxr-xr-x root root`), and I still attempted `rm -rf /rust-cache/monitor365` on the directory itself. Failed with `Permission denied`. Recovered instantly by emptying contents, but the ownership pre-check should have shaped the first command. Root rule: `stat -c %U` the parent before any rm plan.
2. **AGENTS.md edit failed twice on stale read:** sibling modified the file at 03:20; the edit tool correctly refused both attempts. I re-located via `rg`, re-viewed, then succeeded. Cost: 2 wasted round trips. Lesson: with active sibling sessions, ALWAYS re-view immediately before edit, not from memory.
3. **Mild repeat of last session's #1 sin:** my closing summary said the journal "confirms the startup delay is per-restart, not one-time backfill." What the evidence actually supports: the delay occurred on both observed restarts (~4min19s, ~4min06s). Per-restart is now _evidenced_ (n=2), but the _cause_ ("compute-bound startup", implied backfill) remains unverified — I did not profile what the process does pre-bind. Presented inference with more confidence than the data carries.
4. **Deployed sibling's production changes without acknowledgment:** my 03:26 deploy carried sibling commit `66e78231` (Discord alert templates, nvme-collector key fix, focus-follow, zellij auto-attach) live. I reported "the deploy itself was healthy" without noting the cargo. Nobody verified those changes behave correctly in production — and my deploy is what made them live.
5. **End-of-session assumptions stated as fact:** "auto-commit daemon will sweep them" — I never verified the daemon's coverage/state for these files; the tree is still uncommitted at report time (sibling edits intermixed in AGENTS.md would make a naive pathspec commit of that file risky).
6. **Missed cheap quantification:** reclaimed 41G of tmpfs but never captured before/after `/proc/meminfo` or zram `mm_stat` to prove the memory-pressure win; likewise never identified the residual WARN.

---

## e) WHAT WE SHOULD IMPROVE

1. **post-deploy-check should poll, not insta-fail, browser-history** — `curl --retry`/timeout loop (60–120s × N) on `/health`. Every deploy double-restarts the service (switch + `deploy.sh` explicit restart) with ~4.5 min bind delay per restart → a guaranteed false FAIL window of up to ~9 min on EVERY deploy. Same pass: gate the 4 monitor365 probes on `services.monitor365-server.enable` (TODO 51) so real regressions stop being masked by permanent noise. Note: sibling has uncommitted `pre-deploy-check.sh` edits — coordinate before touching.
2. **Fix the browser-history slow init upstream** (bind first, replay/backfill async) OR drop `deploy.sh`'s explicit second restart (the switch already restarts it when the unit changes) — the double restart doubles avoidable downtime on every deploy.
3. **Grep TODO_LIST for known-noise items before investigating smoke FAILs** — monitor365-noise is documented; I spent a re-run + journal spelunking partially re-deriving it (the browser-history half of the investigation WAS worth it).
4. **Run `nix fmt` immediately after every `.nix` edit** — I skipped it; got lucky (0 changes at close). Pre-commit only lints staged files; the daemon sweep may or may not format.
5. **Ownership pre-check before rm** (`stat -c %U <parent>`) — cheap, prevents the d-1 class entirely.
6. **Capture before/after metrics on every reclamation** (df, meminfo, zram mm_stat) — turning "freed ~41G" into evidence costs one command.
7. **Deploy reports should list everything the activation carries** (commits between last deploy and this one), not just "my" changes — production state is a shared ledger with sibling sessions.

---

## f) NEXT — up to 50, ordered

**Disk crisis (root 92%, 57G free — the through-line):** — _2026-08-17: items 1-3 routed TODO_LIST P2 (partition surgery batch), item 4 → P2 (Docker→SSD2), items 5-7 → P0 free-root / untracked_

1. Partition surgery: delete `nvme0n1p9` (98G), grow adjacent BTRFS partition, `btrfs filesystem resize` — needs a careful adjacency/boot-partition plan (p6=/, p9=?)
2. `sudo rmdir /rust-cache` leftover root-owned mountpoint
3. Remove redundant `@cache-home`/`@go`/`@npm`/`@cargo` automounts (hardware-configuration.nix; verify btrbk untouched)
4. TODO 46: Docker data-root → SSD2 btrfs (~sizeable `/data` relief)
5. Re-check btrbk snapshot expiry isn't holding extents (`rm` ≠ free under snapshots)
6. Run a balance pass after partition grow (chunk redistribution)
7. Quantify `/nix` store size; consider `nix.gc` aggressive window given 47G store

**Alert/monitoring correctness (post alert-spam fixes):** — _2026-08-17: items 8 done (probe alerts verified 06-38), 9 done (recovered; sustained-failures meta-check live), 10 → TODO_LIST P3, 11 untracked, 12 → P3, 13 done (converger proven idempotent)_
8. Verify sibling `66e78231` fixes live: did any Discord alert fire (correctly or spam) during 03:26–03:39 browser-history downtime?
9. Verify Gatus browser-history endpoints are green now (no silent gap)
10. Identify the residual WARN in post-deploy-check (I/O pressure vs quickshell)
11. I/O pressure 81% avg10 during deploy — check nix builds sit in `ioTier.build` (BE/7) and not starving interactive
12. Quickshell journal 1-error-line WARN — triage
13. Confirm SigNoz provisioner convergence (no fake RESOLVED/FIRING pairs) on next deploy cycle

**post-deploy-check / deploy.sh hygiene:** — _2026-08-17: items 14 → TODO_LIST P3 (/health poll; urgency reduced by fast startup), 15 done (22-00 monitor365 SKIP-gating), 16 → P3, 17 → P3_
14. Poll-with-timeout browser-history `/health` (e-1)
15. Gate monitor365 probes on enable flag (TODO 51)
16. Reconsider `deploy.sh` explicit browser-history restart (e-2)
17. Pocket-ID SQLITE_BUSY: require N occurrences before FAIL (TODO 51 second half — BUSY cleared on its own again this session)

**Upstream Go repos (carried):** — _2026-08-17: items 18 done (04-32 session tests green), 19-20 untracked upstream, 21 done (storage/v4.7.0 async startup shipped), 22 untracked_
18. `go test ./...` in browser-history (cqrs-htmx jump shipped build-only)
19. `go test ./...` in go-cqrs-lite (dba6f007)
20. `go test ./...` in file-and-image-renamer (fa890d6)
21. Root-cause browser-history pre-bind CPU burn; upstream fix = bind-early/async-replay (needs semantic decision — see g-3)
22. Confirm the 4.5-min init isn't growing run-over-run (compare next restart's journal timestamps)

**Session close-out:** — _2026-08-17: items 23 done (clean commits landed), 24 moot (daemon behavior accepted), 25 done (this docs-health harvest), 26 done (01-34 doc tracked+archived)_
23. Commit the working tree cleanly — SEPARATE mine (hardware-configuration.nix, TODO_LIST.md, AGENTS.md rust-cache hunk) from sibling's (gatus-config.nix, pre-deploy-check.sh, CHANGELOG.md, AGENTS.md SigNoz hunks, 2 untracked status docs). Pathspec discipline this time — last session swept sibling files twice.
24. Verify auto-commit daemon behavior vs the above (don't race it)
25. HARVEST previous report's section (f) into TODO_LIST (docs-health skill) — 3rd session carrying this
26. Owner session to commit `2026-08-16_01-34_DISCORD-ALERT-SPAM-DIAGNOSIS.md` (still untracked)

**Bigger carried items (unchanged):** — _2026-08-17: item 27 moot (monitor365 disabled), 28 → TODO_LIST P2 (hermes bump), 29 → P3 (FastFlowLM), 30 → P3 (start-limit-audit), 31 → P2 (btrfs conversion), 32 dropped (no history rewrite)_
27. monitor365 restoration — start with the empty-journal mystery (unit not starting vs start-limit)
28. Hermes: bump past v0.20.1, delete `registration_lifecycle` patch (TODO 45)
29. FastFlowLM NPU packaging (TODO 52)
30. StartLimitBurst eval-time guard `start-limit-audit.nix` (TODO 53)
31. buildcache btrfs+zstd conversion maintenance window (deferred)
32. History-rewrite decision for `dba6f007`/`a60a646e` vs landing `focus-new-windows.nix` wiring (carried question, now less urgent)

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Partition surgery:** authorize deleting `nvme0n1p9` and growing the root BTRFS partition (p6) into the freed 98G? Online `parted`/`growpart` + `btrfs filesystem resize` is possible without reboot, but it's irreversible disk surgery on a 92%-full production root — and I need your call on timing (now vs a maintenance window with fresh btrbk snapshot verification first).
2. **Priority sequencing:** disk surgery (f-1) vs monitor365 restoration (f-27) vs alert-fix verification (f-8/9) — all three are open and I keep serializing whichever you last touched. What's the order you want?
3. **Browser-history slow init semantics:** if the ~4.5-min pre-bind work is event-replay/read-model rebuild, binding the port _before_ replay finishes means serving potentially stale/empty reads during warmup. Is bind-early-async-replay acceptable for this app, or is serve-only-after-replay a hard requirement? (Determines whether the fix is upstream code, deploy.sh workaround, or just check-tolerance.)

---

**Bottom line:** tmpfs relief real (+41G RAM), `/rust-cache` mount fully retired and verified, smoke driven to green, but the disk crisis on `/` is untouched (92%) and the big irreversible step needs your authorization. Four honest failures this session, none damaging; the two systemic ones (insta-fail smoke checks, double-restart downtime) are cheap fixes with outsized deploy-noise payoff.

---

## Resolution (2026-08-17, docs-health pass)

Section-header verdicts above cover the full f-list (routed/done/moot per item). b-section: b.1 partition surgery → TODO_LIST P2; b.2 root disk → P0 (hit 95% on 08-17 before the pool-session's immich removal freed extents); b.3 automount removal → P2. c-section: c.1 partially done (browser-history tests green 04-32; renamer/cqrs-lint untracked), c.2 done (03-09 fixes verified live), c.3 done (probe alert 06-38), c.4 done (root-caused + fixed: go-cqrs-lite keyset pagination, storage/v4.7.0), c.5 → TODO_LIST P3 (residual WARNs), c.6 done (this harvest). g.1 (partition surgery authorization) → standing TODO_LIST P2 manual item; g.2 — monitor365 moot, alert-spam fixed, disk = P0; g.3 — resolved by the async-startup design (readiness gate, bind early). Archived as resolution-complete.
