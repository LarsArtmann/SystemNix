# Status: nixpkgs-un-pin wave DEPLOYED (gen-1020 live) — paperless 3.5.0 loopback-host fix committed, deploy PSI-blocked

**2026-11-21 02:12 CET — continuation of `2026-11-20_16-55_nixpkgs-unpin-wave-harvest-landed-dnsblockd-fixed-upstream.md` (owner directive: "GET SHIT DONE — the whole todo list"). Session scope: proof #3 → deploy → anchor → post-deploy battery → fallout fix.**

## a) FULLY DONE (verified first-hand)

| # | Item | Evidence |
|---|------|----------|
| a1 | **Proof #3 GREEN** — evo-x2 toplevel keep-going build at the full wave: PROOF_RC=0, `nixos-system-evo-x2-26.11.20261119.0bb8272` (nixpkgs tip 0bb82723 + dnsblockd b3b2cde4 + cv 53e9e8b + taskchampion overlay lift + hermes pin kept) | `~/.cache/lockfloat/toplevel-proof3-20261120.log` tail; 0 `hash mismatch` lines; all 4 `error` grep hits benign (eval-cache busy + `libgpg-error`/`libxcb-errors` filenames) |
| a2 | **Pre-float generator-parity probe (the 16-55 report's top lesson) EXECUTED** at dnsblockd tip b3b2cde4: committed view headers = the DECLARED `templ: version: v0.3.1100`, zero stale v0.3.1123 files | `git -C ~/projects/dnsblockd show b3b2cde4:…gateway_page_templ.go` + `git grep -c 'v0.3.1123' b3b2cde4 -- internal/server/views/` = empty |
| a3 | **Nested-float coherence verified** (report follow-up #15): dnsblockd node carries templ-src v0.3.1100/ed4e766 (matches regenerated views), templ-components v1.27.1/07d2105, go-datastar-static v0.8.0/f909928, the go-cqrs-lite tag family, and infra follows (nixpkgs/flake-parts/go-nix-helpers) intact | python3 lock walk (first-hand, this session) |
| a4 | **Wave DEPLOYED + anchored**: the owner's own `nh os switch` (PID 1623413, 20:50, fish terminal) activated the new graph; after it exited I found **current-system flipped but profile still gen-1018 (UNANCHORED class)** and applied the documented repair: `sudo nix build --no-link --profile …/system <current-system>` (rc=0 → gen-1019) + `switch-to-configuration boot` + boot-mirror sync restart (OK — 50 entries, 403M mirrored). `nix run .#pre-reboot-check` re-run: **17 passed, 5 warnings, 0 failed — SAFE TO REBOOT** | this session's transcript; `~/.cache/lockfloat/prerc-20261120-2200.log`; live: profile = system-1020-link = current-system zfrqkk756 (the 21:58 deploy later landed gen-1020 WITH its own anchor) |
| a5 | **dnsblockd split-brain REPAIRED**: the activation restarted cv (new binary) but LEFT dnsblockd running the OLD pre-wave binary (exe proof: `dnsblockd-9fe62ce` while the rendered unit pointed at `dnsblockd-b3b2cde`). Manual `systemctl restart dnsblockd` → new pid exe = `dnsblockd-b3b2cde` ✓; DNS functional (local zone `immich.home.lan` + upstream) post-restart | `/proc/<pid>/exe` readlinks before/after; `getent hosts` ×2 |
| a6 | **cv verified on the NEW binary**: cv-server MainPID exe = `cv-53e9e8b` (the rev whose vendorHash upstream bakes), unit active, HTTP bound 127.0.0.1:8098, CRM-sync projection + reply loop started post-restart | journal 21:41 lines + exe readlink |
| a7 | **paperless-ngx 3.5.0 loopback-host breakage ROOT-CAUSED + FIXED in-tree**: 3.5.0 semantics — `PAPERLESS_URL` set ⇒ ALLOWED_HOSTS = `[localhost, paperless.home.lan]` (settings/__init__.py `_get_allowed_hosts` + `_parse_paperless_url`), and Django treats `127.0.0.1` ≠ `localhost`, so paperless-gpt's pre-start curl probe (and triage/exporter loopback API calls) got DisallowedHost-400s → gpt crash-looped 45 restarts, paperless-web journal 383 lines/min. Fix: `PAPERLESS_ALLOWED_HOSTS = "127.0.0.1,localhost"` in paperless.nix settings (upstream itself appends localhost for exactly this health-check class). **User-facing paperless was NEVER broken** (Host: paperless.home.lan → 200, 7247 B) | commit `14ec73b28` (eval-green, alejandra-clean); first-hand settings read at `/nix/store/j5fwx3xrz…-paperless-ngx-3.5.0/lib/paperless-ngx/src/paperless/settings/__init__.py:450-483`; probe `python3 urllib` ×2 |
| a8 | **Doc closures landed**: upstream.md dnsblockd row → RESOLVED (with attribution caveat + tag-re-point residual preserved); pipeline.md coherent-pair row REMAINING → RESOLVED. Commit `60eae778c` | git show 60eae778c |
| a9 | **Daemon-race repair ×2** per CONTRIBUTING policy: daemon committed my paperless fix (9207c36ee) and my doc closures (ff882c5f8) footless mid-flight; both verified (`git show --stat`) and amended-forward into properly-messaged commits (14ec73b28, 60eae778c) while still HEAD. Both are now on origin (pushed externally by owner/daemon/mr — not by me) | origin/master contains both |
| a10 | **Deploy discipline held under 4-way contention**: BuildFlow `--fix` loops, the owner's nh, a 39-min deploy.sh (nh-core PANIC exit — see d2), and a flock-bounced 22:18 attempt; my watcher fired once (20:30) and was correctly pressure-refused, and I killed my own re-arm (21:18) the moment /proc showed two live switches — no double-activation, no flock damage | deploy logs 2026-11-20_{20-30-23,20-45-03,21-23-44,22-18-55}.log |

## b) PARTIALLY DONE

| # | Item | Remaining |
|---|------|-----------|
| b1 | **The paperless fix (14ec73b28) is committed + eval-green but NOT DEPLOYED** — paperless-gpt still `failed` live; the 01:34 deploy attempt was pressure-refused (code=12, 3s) and a patient fire-loop (double-calm PSI gate, ≤3 fires) is ARMED as of 02:11 (fstrim + llama-vlm-cap nightly storms hold io PSI 32-75%) | one clean deploy window → verify gpt active + journal silenced |
| b2 | **Post-deploy battery ran once (22:02) against the mid-activation state**: 183 PASS / 6 FAIL / 3 SKIP / 18 WARN, PDC_RC=3. The 6 FAILs: (1) CV browser-render smoke (pages load, don't RENDER), (2) Paperless login page lost the Pocket ID auto-submit flow (3.5.0 UI change suspect), (3) paperless-gpt not active (= a7, fix pending), (4) Bank-Sync sync_errors_total > 0, (5) paperless-web 383 journal lines/min (= a7 cascade), (6) dnsblockd filter-proxy keys present but unit not active (probed BEFORE my 22:12 dnsblockd restart — possibly stale) | re-run the battery after b1 lands; triage (1)(2)(4)(6) on fresh state |
| b3 | **flake.nix f4a03c00 comment-tense refresh** (16-55 report follow-up #25): all 3 sites located (lines 29-35 header OK as history; lines 1462-1465 hermes edge + 1489-1491 monitor365 edge read as if the pin still exists). Deliberately NOT edited tonight — flake.nix is eval-relevant; an edit would have voided §11 mid-battery and a commit would burn a full eval round under storm load | one flake.nix-only commit in a quiet window |

## c) NOT STARTED

- SigNoz impersonation check + §17 memory sweep + §19 restic freshness as STANDALONE re-verification post-gen-1020 (the 22:02 battery covered them in aggregate; SKIP/WARN legs not individually re-verified by this session).
- The battery's 18 WARNs triage (scope-cut tonight).
- Explicit standalone `nix flake check --no-build --all-systems` capture (eval legs ran via pre-commit + the deploy battery; no clean standalone capture exists for gen-1020's exact tree).
- Runbook note for the 3.5.0 ALLOWED_HOSTS semantics in docs/services/paperless.md.

## d) TOTALLY FUCKED UP (own errors, no embellishment)

1. **Fired a deploy watcher into a storm I had already measured** (20:30): BuildFlow's parallel `nix build` was holding PSI; pipeline.md row 13's "do NOT fire into an unresolved storm" lesson was in-context and I armed anyway. The gate refusal was correct and cost a battery round-trip.
2. **Re-armed the watcher (21:18) with a process-blind gate**: quiescence checks tree+mtimes only; the OWNER's 20:50 `nh os switch` AND a 39-min deploy.sh were mid-flight and invisible to it. I caught it via /proc forensics (children: `sudo … switch-to-configuration test`; parent chains) and killed my arm manually — but the /proc re-check existed in my FIRST pre-flight and I skipped re-running it before the second arm. **Process-check EVERY arm**, not just the first.
3. **sudo quoting bug**: `sudo "$XL/bin/switch-to-configuration boot"` passed `boot` INSIDE the quoted path → command-not-found + wasted round (correct: `sudo "$XL/bin/switch-to-configuration" boot`).
4. **PIPESTATUS assumption in the tool shell** (mvdan/sh, not bash): masked two rc reads (boot_rc empty twice). rc capture after pipes is unreliable here — use `cmd; rc=$?`.
5. **mv/misread near-miss on pipeline.md**: my multiedit hit `file modified since read` (parallel session touched it at 22:22:45); the re-read showed a NEW row inserted above my target and an mtime-only touch with empty diff. Caught before any corruption, but the first edit already rode a 2-minute-old read — the content-pin discipline is check-BEFORE-EVERY-edit, not once per file.

## e) WHAT WE SHOULD IMPROVE

1. **deploy-when-quiescent needs a process-liveness gate**: `pgrep -f 'nh os|bin/deploy'` empty alongside clean+cold tree — tonight's near-miss (my 21:18 arm under two live switches) is the exact case it exists to prevent.
2. **deploy.sh pressure gate should print its threshold + a 60s PSI trace on refusal** — my sampler (avg10<25) raced the gate's own instant twice (01:34 refusal 3s after a 23.79 reading); without the gate's exact number, patient fire-loops guess.
3. **Restart-completeness check** (the dnsblockd split-brain): compare every active unit's running exe store path vs its rendered unit ExecStart — a mechanical split-brain detector would have caught a5 without the manual exe walk. Candidate: post-deploy battery leg (cheap, `readlink /proc/<MainPID>/exe` per active service).
4. **nh panic** (`crates/nh-core/src/command.rs:931:20`, 20:45 deploy.sh's nh, exit 1 after 2333s — "config NOT activated"): upstream nh bug candidate; verify-before-filing first, then github-voice.
5. **paperless.md runbook**: new loopback consumers of paperless-web need the ALLOWED_HOSTS entry (or the vhost Host header), never per-client Host workarounds — one server-side line covers all.
6. **Long-eval contention**: proof 3 hit `eval-cache … sqlite busy (ignored)`; the 20:45 deploy.sh eval ran 39 min under storm load. The eval-cache lock contention class is worth one datapoint in docs/agents/nix-flakes.md if it recurs.

## f) NEXT THINGS (priority order)

1. **DEPLOY the paperless fix** (14ec73b28) — the armed fire-loop does it on the first double-calm window; if it exhausts (3 fires), fire manually in the ~03:30+ quiet (03:00 monitor365 backup window — avoid).
2. Post-deploy verification chain: paperless-gpt active + restart counter reset; paperless-web journal rate back to baseline; `getent hosts` ×2; anchor by NUMBER.
3. Re-run `scripts/post-deploy-check.sh` (capture-once) — expect FAILs (3) and (5) to clear; triage (1)(2)(4)(6) on the fresh baseline.
4. dnsblockd filter-proxy investigation (battery FAIL 6): does b3b2cde's config still declare the proxy keys, and which unit name should be active — possible naming drift at tip.
5. Paperless OIDC auto-submit probe (battery FAIL 2): 3.5.0 login-template change vs our probe's string pins — fix the probe or the oidc-setup provisioner, decide after journal read.
6. CV browser-render smoke (battery FAIL 1): `/tmp/.smoke-cv-render.log` — CV renders via the NEW 53e9e8b binary; string pins passed but render broke; likely a js/css asset pin or CSP change at tip.
7. Bank-sync error counter (battery FAIL 4): `bank_sync_sync_errors_total > 0` — journal + which cycle failed since restart.
8. flake.nix f4a03c00 tense refresh (b3) — flake.nix-only commit, quiet window.
9. Add the process-liveness gate to deploy-when-quiescent (e1) + negative-test it.
10. Add the restart-completeness detector to post-deploy-check (e3).
11. deploy.sh refusal-threshold surfacing (e2).
12. Standalone `nix flake check --no-build --all-systems` capture for the gen-1020 tree (c).
13. SigNoz impersonation + §17 + §19 standalone re-verification post-next-deploy (c).
14. docs/services/paperless.md ALLOWED_HOSTS runbook note (e5).
15. nh panic upstream issue (e4) — verify-before-filing gate first.
16. Triage the battery's 18 WARNs.
17. Eval-cache SQLite contention datapoint (e6) if it recurs.
18. `docs/todo/services.md` + TODO_LIST harvest rows for b1/b2 (landing with this report — see below).
19. Watch the next `nix flake update nixpkgs` float: paperless-ngx 3.5.0-class semantic changes are now the expected failure shape for loopback consumers fleet-wide (any other Django/PAPERLESS_URL consumer needs the same allowlist audit).
20. When proof-green + deployed: annotate the 15-21 superseded report's pointer with "proof #3 + deploy DONE 2026-11-20/21" (its NOT-VERIFIED line is now stale).

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **dnsblockd upstream attribution**: WHO executed the fix chain (bcdd194f vendor-hashes → b3b2cde4 "regenerate stale templ and Tailwind artifacts") and the three lock floats (7e80d058f / c749eb8aa / 9b463facc)? I closed the upstream.md row with an explicit attribution caveat — if that was your own manual session (the 20:50 fish-terminal `nh os switch` was clearly yours), say so and the caveat retires; if another agent session owns it, I'd like to know which so future row closures don't co-claim.
2. **templ-components `v1.27.1` tag re-point** (97c49407 → 07d21051, 2026-11-19, under dnsblockd): deliberate fix-forward or accident? Tags MUST be immutable per repo doctrine — if deliberate, the residual in the closed row retires; if accidental, the tag needs restoring + re-cutting and the lock re-floats.
3. **Push arrangement**: my two commits (14ec73b28 fix, 60eae778c docs) reached origin WITHOUT any action from me (mr push / your session). I treat push as owner-territory and will never push unasked — confirm that's the standing arrangement, and whether the nightly `mr push` is expected to sweep agent commits as a matter of course.

---
**Harvest (authoring-time, per the status-report rule):** §f.1/b1 → TODO_LIST `[ready]` row + `docs/todo/services.md` paperless row; §f.4-5 → `docs/todo/services.md` rows; §e1/e3 → `docs/todo/pipeline.md` row. One commit with this report.
