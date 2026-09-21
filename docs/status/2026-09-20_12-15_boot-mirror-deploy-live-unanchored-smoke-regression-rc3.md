# Boot-Mirror Deploy: System LIVE but UN-ANCHORED — rc=3 Smoke Regression (Browser History 503), Profile Stuck at system-785

_Sequence: continuation of `2026-09-20_11-00_nodejs-slim-shim-not-reaching-drv-deploy-rc1.md`. Covers 11:02 → 12:15 (2026-09-20). User directive: "just use a working cached version" + full autonomous execution; queue-driven, pressure-gated. This report ends in a WAIT state per user instruction._

## Headline

**The 20b1ddd system is RUNNING** (`/run/current-system` = `7k2fg7770w80gvks0h38k0libqqa38dy-nixos-system-evo-x2-26.11.20260919.20b1ddd`), the nodejs blocker is solved exactly as the user demanded (cached, zero from-source nodejs builds), and `/boot-mirror` is mounted with the correct UUID — **BUT** the deploy exited **rc=3** (NEW smoke regression: Browser History `/health` 503 + a Pocket ID check), and **the numbered profile did NOT advance (still `system-785`)**. This is the un-anchored-generation class: **ANY reboot before the next clean deploy REVERTS the running system to system-785.** The queue self-stopped for diagnosis as designed (11:53:21).

## Timeline (this window)

| Time | Event |
| --- | --- |
| 11:02 | Resumed from 11:00 handoff. User: "just use a working cached version shit" |
| 11:06 (discovered) | Daemon commit `8253c632` (11:06:04) bumped **ROOT nixpkgs** `e554fab` → `20b1ddd` (20260918) — root input maps to lock node `nixpkgs_4`; author unknown (not me) |
| 11:08–11:14 | **Shim non-reach mechanism PROVEN** via `nix why-depends --derivation` on the re-evaluated toplevel: `toplevel → system-path → hermes-agent-0.21.3 → nodejs-26-npm-12 → nodejs-26.9.0 → nodejs-slim-26.9.0`. The hermes-agent flake builds its nodejs chain against the **followed root nixpkgs via `inputs.nixpkgs.legacyPackages` — OVERLAY-LESS** (lock node: `"nixpkgs": ["nixpkgs"]`). `overlays/shared.nix` can structurally never reach it — hypothesis (a) of the 11:00 report, exact form confirmed |
| 11:10 | `20b1ddd#nodejs-slim_26` = 26.9.0 carrying upstream fix `089b82f9` → drv `ffrcbs2y…`, **output already VALID in store** (`xikrmk4i…`, 110 MB) = the user's "working cached version", zero nodejs compilation needed |
| 11:12 | **Shim found actively HARMFUL**: on 20b1ddd it forked a THIRD drv (`fh8cr85q…`, our overlay's postPatch) that no cache serves — would have forced 2 from-source nodejs builds. Removed the shim (executing its own documented drop-condition) |
| 11:16 | Daemon raced my commit into heuristic `69553ebd` (only my file, verified) → amended to proper `1bfe5ae2` (hooks + flake check green) |
| 11:18–11:22 | Verification battery: failing drv `njhj371` **GONE** from toplevel graph; dry-run build set **50 → 31 derivations, 0 nodejs**; toplevel drv changed `cfypaqhx` → `m56351wi` (drv-path-diff doctrine satisfied) |
| 11:25:27 | Queue v6 fired (gate green ×2 immediately); deploy started |
| ~11:35 | Build phase done in ~10 min (llama-cpp + hermes chain largely already built by the 11:06-bumper's parallel work — my "llama-cpp long pole" prediction was wrong) |
| ~11:45–11:53 | Activation + provisioner restart chain (paperless OIDC/dashboard restarts, etc.) |
| 11:53:21 | **deploy rc=3**: 7 smoke checks failed, of which **NEW vs previous baseline: "Browser History (localhost:8087) — expected HTTP 200, got 503" + a Pocket ID entry**. Queue stopped for diagnosis (by design) |
| 12:15 | State capture: running = 20b1ddd toplevel; profile = `system-785-link` (**UN-ANCHORED**); `/boot-mirror` mounted `/dev/nvme1n1p1` vfat rw, **UUID `4F53-C156` correct**; mirror contents unreadable as user (`dmask=0077` — root-only, §11 owns that check) |

## a) FULLY DONE

1. **Shim non-reach mechanism proven** (why-depends chain): hermes-agent's flake evaluates its packages against the followed root nixpkgs WITHOUT SystemNix overlays — the 09-19 shim (`8740c661`) was structurally dead code from the moment it landed
2. **User's directive delivered**: nodejs-slim resolved to the cached, upstream-fixed build (`ffrcbs2y`, output valid in store) — the failing `njhj371` drv is provably out of the graph; **zero from-source nodejs builds** in the deploy
3. **Harmful shim removed** before it could hurt: on 20b1ddd it forkged an uncacheable third drv forcing from-source nodejs — commit `1bfe5ae2` (amended from daemon sweep `69553ebd`)
4. Full verification battery BEFORE relaunch: dry-run 50→31 builds, 0 nodejs, toplevel drv identity changed
5. **Queue v6 → deploy → activation succeeded**: the 20260919.20b1ddd system IS RUNNING (first profile-era advance since system-785 on 09-18)
6. `/boot-mirror` mounted with correct UUID `4F53-C156` (F06: verified)

## b) PARTIALLY DONE

1. ~~**M1/F05 deploy**: system live but **UN-ANCHORED** — profile `system-785` ≠ current-system 20b1ddd; a reboot reverts. Recovery is known: fix the smoke regression → re-run deploy → clean activation bumps the profile~~ done (closed — system-786 anchored 14:08 (fc49dbe5), three-way verified per 15-30)
2. ~~**Mirror verification (F06–F09)**: mount + UUID done; contents/df/sync-unit state NOT yet verified (need root via pre-reboot-check §11 — the vfat mount is dmask=0077 root-only, plain `ls` as user is Permission denied, NOT an empty mirror)~~ done (F06–F09 done per 15-57 §a.3 (sync diff-gate PASS, df 312M/4.0G))
3. ~~**rc=3 regression captured but NOT diagnosed**: Browser History `/health` 503 (server down/degraded — agent timer/token/collector checks all PASS, so it's the server unit specifically) + one Pocket ID entry (exact line not yet extracted)~~ done (root-caused in 13-58 (AGENT_FRESHNESS gate deadlock, fixed live 13:54:51; Pocket ID = transient SQLITE_BUSY); quiet-day 503 by-design filed upstream (#26))

## c) NOT STARTED (all gated on a clean rc=0 deploy)

1. ~~F10 pre-reboot-check §11 WARN-grade~~ done (F10 done per 15-30 (§11 WARN grade green))
2. ~~F11–F12 `boot-mirror-activate` (Samsung first in BootOrder)~~ done (F11–F12 done per 15-30 (Boot000C Samsung-first))
3. ~~F13 pre-reboot-check §11 FAIL-grade~~ done (F13 done per 15-30 (23-pass/0-fail strict grade))
4. ~~F14–F15 CHANGELOG entry + Samsung plan-doc ticks 6/7/9~~ done (F14–F15 done (CHANGELOG boot-mirror entry + ticks 6/7/9 per 15-57 §a.8))
5. ~~F16 pathspec commits + push (authorized)~~ done (F16 done — pushed 541fab97 (15-57 §a.9))
6. ~~F17 reboot handoff to user~~ done (F17 reboot handoff = the 15-30/15-57 reports (user reboot still pending))
7. ~~AGENTS.md doctrine harvest (see e)~~ done (harvest landed — AGENTS.md anchor-check-first + nodejs-slim saga bullets)

## d) TOTALLY FUCKED UP (honest ledger)

1. **I shipped a deploy with a NEW smoke regression.** I fired the queue without reading the previous run's smoke baseline and without a triage plan for the big nixpkgs delta (0917→0918 + hermes 0.21.3 + parallel batch). The exit-3 baseline-diff gate exists precisely for this and I treated "build set verified" as the whole risk surface
2. **The system is now UN-ANCHORED on my watch**: rc=3 aborted deploy.sh after activation but before the profile advanced. Until the next clean deploy, ANY reboot reverts the box to system-785 — the exact hazard class documented in AGENTS.md. I did not check the anchor until AFTER the queue had already stopped
3. **Built on an unattributed lock change**: the 11:06 root nixpkgs bump appeared, I verified its EFFECTS thoroughly but never established WHO made it (user? parallel session? fmt re-lock accident?). If accidental, it deserves review; I proceeded because it matched the user's directive in substance
4. **Prediction miss**: I flagged llama-cpp as the long pole (wrong — cached); the actual risk (smoke baseline drift) was not on my list at all
5. **Carried from 09-19 (mine to own)**: the shim was accepted as "the fix present" without drv-path identity proof — today's drv-path-diff rule would have exposed the non-reach in minutes instead of a day

## e) WHAT WE SHOULD IMPROVE (structural)

1. **drv-path-diff verification doctrine → AGENTS.md**: any overlay/override "fix" must be proven by the affected derivation's path CHANGING from the previously-failing path, evaluated from the CONSUMING flake. Eval-green is the weakest signal
2. **Overlay-non-reach class → AGENTS.md**: packages built INSIDE followed flake inputs evaluate against overlay-less `legacyPackages` — SystemNix overlays cannot reach them. Fixes for their dependency chains must go into the input's own flake or via the lock, never into overlays/shared.nix
3. **Anchor check must be step 1 after ANY deploy rc** (including non-zero): `readlink` profile vs current-system before anything else — I did it last
4. **Pre-deploy baseline review**: before firing a deploy that carries a big nixpkgs delta, read the last smoke baseline and pre-triage which failures are known vs would be NEW
5. **deploy.sh ordering candidate**: anchor the numbered profile BEFORE post-deploy-check, so an rc=3 (smoke regression) never leaves the running system reboot-revertible
6. **Harmful-shim lifecycle rule**: every shim whose drop-condition is "the lock carries it" should also be REMOVED the day the lock carries it — a surviving shim actively breaks substitution (this exact case)

## f) NEXT (ordered, up to 50)

1. ~~Diagnose Browser History 503: unit state + journal (`journalctl -u browser-history -n 50`), classify against the known SQLITE_READONLY upstream-hold class vs deploy-restart timing vs nixpkgs-delta effect~~ done (root-caused in 13-58 — AGENT_FRESHNESS health-gate deadlock; gate now accepts any answered HTTP status)
2. ~~Extract the exact Pocket ID NEW-failure line from the deploy log (full context)~~ done (extracted in 13-58 — Pocket ID entry = transient SQLITE_BUSY)
3. ~~Review the other 5 failed-but-not-NEW checks (CV pipeline-store FAIL, CV render FAIL, …) — confirm they are the known baseline holds, not fresh decay~~ done (confirmed known baseline holds in 13-58)
4. ~~Fix whatever 1–2 surface; re-run `nix run .#deploy` → expect rc=0 + profile advances past system-785 (F05 COMPLETE)~~ done (system-786 anchored 14:08 (fc49dbe5); 787/791 followed)
5. ~~Verify anchor: `readlink /nix/var/nix/profiles/system` == `/run/current-system` ≠ system-785~~ done (three-way anchor verified per 15-30)
6. ~~F06–F09 finish: §11 output covers mirror contents (root), sync unit ran clean, df~~ done (done per 15-57 §a.3)
7. ~~F10 `nix run .#pre-reboot-check` → exit 0, §11 WARN-grade~~ done (15-30 §11 WARN grade green)
8. ~~F11–F12 `nix run .#boot-mirror-activate` → Samsung first in BootOrder, QLC 0x0001 second~~ done (15-30 — Boot000C Samsung first, QLC second)
9. ~~F13 re-run pre-reboot-check → exit 0, §11 FAIL-grade~~ done (15-30 — 23-pass/0-fail strict grade)
10. ~~F14 CHANGELOG entry (boot-mirror shipped + nodejs saga + rc=3 lesson)~~ done (CHANGELOG boot-mirror entry landed)
11. ~~F15 tick Samsung plan-doc items 6/7/9 (leave 8 = reboot)~~ done (ticks 6/7/9 per 15-57 §a.8)
12. ~~F16 pathspec commits + push (authorized)~~ done (pushed 541fab97)
13. ~~F17 reboot handoff (the ONLY user-owned step)~~ done (handoff delivered in 15-30/15-57)
14. ~~AGENTS.md harvest: overlay-non-reach, drv-path-diff, un-anchored-rc3, harmful-shim-lifecycle~~ done (landed in AGENTS.md (anchor-check-first, drv-path-diff, overlay-non-reach, harmful-shim-lifecycle))
15. ~~nvme enumeration drift: mirror sits on `nvme1n1p1` NOW (handoff said Samsung = nvme0 post-04:17) — confirm by-id/UUID discipline holds (fstab mounts by UUID/label, so cosmetic, but the disk-truth note needs updating)~~ done (closed — fstab/by-UUID discipline held (13-58 f.38); cosmetic only)
16. ~~Identify the 11:06 lock bumper (if not the user: parallel-session journal/git forensics)~~ done (identified — parallel deploy session (19-47 §a.9; daemon commit 8253c632))
17. ~~Carried side sweep: identify the 09:46–10:09 deploy-lock holder (~25 min of rc=13 cycling)~~ done (moot — holders were the parallel deploy.sh/nh pair (12-26 §d.1))
18. ~~Carried side sweep: empty `nix log` on the old failing drv (GC'd log)~~ **Won't implement — superseded by the -L rebuild.**
19. ~~Carried side sweep: attic/cache.home.lan coverage for nixpkgs-era nodejs~~ **Won't implement — moot — zero nodejs builds post-bump.**
20. ~~Confirm the REMOVED-path entries this deploy shipped are expected: `51-hdmi-monitor-priority.conf` (smart-audio resolution, yes), `bank-sync-*-fish-completions` (parallel session's change? bank-sync smokes PASS — verify nothing else moved)~~ done (confirmed expected (13-58 §a.11))
21. ~~M8 first-nightly drift watch (post-reboot): sync re-ran, no drift, df stable~~ done (sync green through system-791 (19-47 §b))
22. ~~M9 llama-vlm coordination (models still dark, owner decision)~~ done (routed into docs/todo/ai-stack.md (19-47 §a.11))
23. ~~M10 ExecStart list-shape audit (systemd-shape-audit candidate, unchanged)~~ done (routed to the systemd-shape-audit extension row (19-47 §a.11))

## g) QUESTIONS (cannot figure out myself)

1. ~~**Was the 11:06 root nixpkgs bump (`e554fab` → `20b1ddd`, daemon commit `8253c632`) yours or your parallel session's deliberate act?** It is exactly what your "cached version" directive wanted (carries upstream nodejs fix `089b82f9`), so I built on it — but if it was an accident (fmt re-lock class), say so and I will review the rest of its 1-day delta consciously~~ done (answered — deliberate parallel-deploy-session bump (19-47 §a.9))
2. ~~**Was the 04:17 reboot yours?** (Carried from the 11:00 report — if not, it is freeze #7 candidate and needs crash forensics; kdump should hold a vmcore if it panicked)~~ done (answered — 04:17 attributed to the parallel deploy session (19-47 §a.9))
3. ~~**When do you intend to reboot?** The running system is UN-ANCHORED until the next clean deploy lands — any reboot before that reverts to system-785. Knowing your reboot intent calibrates how hard to push the Browser-History fix + re-deploy (minutes vs careful hours)~~ done (superseded — system re-anchored 14:08; user reboot carried by the 15-30/15-57 handoffs)

## Ops state right now (12:15)

- Queue: v6 EXITED (rc=3 stop, by design). Relaunch after the smoke fix: `systemd-run --user --unit=boot-mirror-deploy-v7 --collect $HOME/.local/state/boot-mirror-queue.sh`
- Running system: `nixos-system-evo-x2-26.11.20260919.20b1ddd` (NOT profile-anchored)
- Profile: `system-785` (stale — the hazard)
- /boot-mirror: mounted, UUID `4F53-C156` ✓, contents root-only
- Firmware: unchanged (QLC `Linux Boot Manager` 0x0001 first; activation not yet run)
- Deploy log: `~/.local/state/boot-mirror-deploy.log` (rc=3 at 11:53:21; full smoke section above the rc line)
