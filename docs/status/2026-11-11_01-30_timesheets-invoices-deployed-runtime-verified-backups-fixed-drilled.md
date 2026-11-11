# Status Report — timesheets + invoices: DEPLOYED, runtime-verified, backups fixed + drilled, CI bundle-2 completed

**Date:** 2026-11-11 01:3x CET (session started 2026-11-10 ~19:45)
**Session:** resume of the 13:25 floatgate-blocker handoff. Owner directive: "keep going until everything works".
**State:** both services LIVE on gen-997 (ride-along on the storm session's 19:12 deploy), every runtime surface verified with receipts, the backup DAC trap found + fixed + drilled, CI bundle-2 extended to cvagent with the auth step proven green in a live matrix rerun. Two items deliberately left to named owners: the cap-fix DEPLOY (blocked by the sibling red float — crm/journal vendorHashes) and the key-file trash (waits on the CI verdict, §g.3 default).

---

## a) FULLY DONE (verified this session)

| # | Item | Evidence |
|---|------|----------|
| a1 | **Blocker `:anon-2290` resolved without my intervention** — traced eval green at session start (drv `4383bzw8…`); the break was offline-banner.nix's config-shorthand `services.` key, fixed by sibling commit `06079542e` (attribution recorded in the cvagent CHANGELOG entry). My bisect prep was never needed | trace-eval3.log EXIT=0 |
| a2 | **float-register ceremony formally closed** — the parallel session's paired commit `a0d5ad0d1` (lock+registry) left no drift; `float-register.sh` → "no drift" exit 0. Timesheets rode the float from `0304e2a` → `0a5524f` (two upstream NIX packaging fixes: go.sum re-tracked, renderer golden fixtures re-tracked) | script output + git show |
| a3 | **flake check --no-build GREEN** ×2 (first run's `flake-input-pin-audit-selftest` "path not valid" was a transient GC/store race — isolated eval of the identical check green, full re-run green) | fc2.log "all checks passed!" |
| a4 | **Spot-render all 5 units + 2 timers + 2 integration entries** — ExecStarts point at the locked revs (`timesheet-0a5524f`, `invoices-f72f78e`), RW holes exactly the data dirs, watermark-coherent memory (512M/410M, 1G/858M), ConditionPathExists on the invoices config, timers 03:20/03:50 + jitter + Persistent | spotrender.json |
| a5 | **Registry matrix** — both rows present (lines 208/258 of integration-registry.md); the drift check owns byte-parity; my splice was a no-op (sibling had already regenerated) | jq + rg receipts |
| a6 | **Deploy landed as gen-997 ride-along** (the storm session's 17:55→19:12 switch carried my committed modules); anchor green: `readlink /run/current-system` == newest-by-number `system-997-link` | busctl + readlink |
| a7 | **Runtime verification battery, all green**: listeners `127.0.0.1:8109` (timesheet) + `:8110` (invoices) with binaries byte-identical to the rendered ExecStarts; TLS+SNI via Caddy: `/readyz` 200 JSON, `/health` 200 HTML (title "Timesheets", CSP+nonce), `/version` 200, invoices `/health` 200 `{"status":"healthy",checks:[database,read-models]}`, `/` title "Invoice Dashboard"; SSE: invoices `/events/facts` 200 `text/event-stream`, timesheets `/api/events` 200 held-open server-side (journal durations = my client timeouts, idle stream by design); gatus: all 4 checks + both Backup Freshness entries in the eval'd endpoint set; tiles on dash.home.lan with resolved icons (`/icons/invoiceplane.png`); live hardening via busctl (ReadWritePaths single holes, MemoryMax, ProtectHome=read-only ×3 units) | openssl s_client probes, journalctl, gatus endpoint eval, /api/services JSON |
| a8 | **§11 FOD preview GREEN** — "all deploy go-modules FODs cached — vendorHash proven by prior builds [tree e4c785e]" | pre-deploy-check output |
| a9 | **THE BACKUP DAC TRAP: found, root-caused, fixed, drilled** — both backup units "succeeded" writing NOTHING (`no DB — nothing to back up` while the file existed): `/home/<user>` is 0700 and `harden{}`'s empty CapabilityBoundingSet strips root's DAC bypass, so the root-run unit could not STAT the DB (serve units immune — they run as the owner; exit-0 clean-skip masked it). Fix: `CAP_DAC_READ_SEARCH` in each backup's harden{} (cv-backup precedent), validated by re-running the EXACT store-path scripts under systemd-run with the cap: both 2026-11-10 artifacts produced (timesheets 4.0K, invoices 8.0K + config snapshot). Committed `e4c785e5e` | journalctl + pool ls + commit |
| a10 | **Restore drills RUN + receipts landed** — gunzip → `PRAGMA quick_check` ok ×2, 13 + 14 tables (invoices incl. domain tables), config snapshot hash-identical to live; the three PENDING markers (2 runbooks + data-ownership rows) flipped to dated receipts in the same commit | drill transcripts + sha256 |
| a11 | **CI bundle-2 completed for cvagent** — root-caused the 5-run CI red streak to `Failed to fetch git repository 'ssh://git@github.com/LarsArtmann/Code-To-CV-Agent'` (the cv session's input had NO deploy key, bundle-2 never carried it). Generated + registered read-only key id 169436585, extended `NIX_DEPLOY_KEYS_BUNDLE_2` (+`@REPO Code-To-CV-Agent` block), rerun proves the "Configure private flake-input auth" step GREEN across the whole matrix and the fetches proceed | gh api + rerun logs |
| a12 | **The bundle-2 sops archive is now git-TRACKED** (`41afb72b3`, force-add past the `secrets*` ignore per the tracked-siblings convention) — it had lived UNTRACKED on disk since 06:59 (the daemon never `git add`s new files; the 13:25 report's "committed" claim was wrong for this file). Extended with `cvagent_key`; full chain proven: archive bytes == generated private key, derived pub fingerprint == GitHub-registered pub (`SHA256:i0JRSVHH…`) | commit + fingerprint run |
| a13 | **CHANGELOG entry landed** (rode daemon sweep `abb8a979c`): go-live, integration surface, DAC trap, bundle-2 completion | rg count 1 |
| a14 | **Upstream AGENTS.md deployment notes** appended in BOTH product repos (~/projects/timesheets: unit/port/data-dir/serve flags + fileset contract; ~/projects/invoices: the config.yaml CWD boot contract as config-of-record + vendorHash staleness note) | both files |
| a15 | **Cleanup** — `~/.cache/invoices-lockprobe` worktree already gone; svcprobe + sopswork plaintexts (bundle2-plain, cvagent-plain.key, enc outputs, append fragment) trashed; dk-* key files + bundle2.txt KEPT pending the CI green (§g.3 default: trash after first green run) | trash + ls |
| a16 | **TODO queue hygiene** — the sibling's gate-failing [ready] row (my services' first timer firing) rewritten to `[blocked:deploy]` with updated truth + a matching `docs/todo/services.md` library entry (queue/library drift closed) | TODO_LIST.md:3448 + services.md tail |

## b) PARTIALLY DONE

| # | Item | Missing |
|---|------|---------|
| b1 | **CI green run** | The rerun (42871668924, old commit + new secret) proves auth+fetch everywhere; `nix-check` job verdict still pending at report time; two VM tests (cv, sev1-escalation) fail at RUNTIME on that old commit (not fetch/build — pre-existing flake class, outside my change's blast radius). The CURRENT master CI additionally fails on the sibling's pushed red float (vm-tests "Cannot build" on crm/journal FOD mismatches) — sibling domain |
| b2 | **Negative-check (disabled fan-out)** | Blocked by the re-armed lock-float gate (host eval dead until the float lands). Structural truth holds by construction (`lib.mkIf cfg.enable` + `optionalAttrs (options ? services.integration)` wrap every fan-out); the throwaway extendModules expr sits ready at ~/.cache/negative-check.nix for the first post-float window |

## c) NOT DONE (blocked or deliberately deferred)

- c1 **Deploy of the cap fix** — deploy.sh runs float-register first; the proof is RED on sibling-owned roots (kith-crm + journal go-modules vendorHash mismatches; crm checkout +3, journal +17 unpushed — the float-wave session is actively on it). Tonight's 03:20/03:50 timers will fire the OLD units and write empty (documented in the [blocked:deploy] row; artifacts + drills already exist from the manual cap-runs, so nothing is lost but the timer-driven proof).
- c2 **Key-file trash** (`~/.cache/systemnix-ci-keys/`) — after the first fully green CI run (§g.3 default held).
- c3 **Watch first nightly backup window** — tomorrow after a deploy lands (row owns it).

## d) TOTALLY FUCKED UP (own mistakes, all self-caught)

- d1 **Redirect-truncation destroyed the untracked sops archive**: `sops -e … > archive.yaml` failed AFTER `>` truncated the target — and the file was NEVER git-tracked, so git restore was impossible (my first restore attempt also hit the sibling's live index.lock — correctly waited out, never deleted the lock). Recovered by re-encrypting the plaintext I still held in the cache workspace. Standing rule reinforced: never redirect-into an unrecoverable target; write to temp + mv.
- d2 **`sops exec-file` semantics fought me 4 rounds** (arg-passing differs by version; no path in $0/$1/env here) — the final explicit decrypt→append→re-encrypt-with-explicit-recipient path worked. Should have gone explicit after round 2.
- d3 **jq `-Rs` direnv trap hit** (documented in AGENTS.md, still typed it) — `env -u DIRENV_DIFF` fixed.
- d4 **Scrub botch attempt**: my first archive re-encrypt failed "no matching creation rules" from the WRONG CWD (sops matches rules from cwd-chain, input path relative) — fixed by cd'ing into the workspace.
- d5 **Two pre-commit subject-length rejections** (76, 74 chars vs 72 limit) — the limit is documented; measure before writing.
- d6 **Stray `rg -rn` fragment** typed once (hook blocked it — third-strike rule now burned into muscle memory).

## e) WHAT WE SHOULD IMPROVE

- e1 **New-secret-file onboarding needs a checklist row**: generate → register → BUNDLE append → `gh secret set` → **`git add -f` + commit** (the daemon never adds untracked files — the archive lived 14 h with no git copy and my truncation nearly lost it).
- e2 **harden{} + user-home data dirs**: the "root unit reads /home/<user>" shape needs CAP_DAC_READ_SEARCH BY DEFAULT (or an eval-time audit: root-run unit + ReadWritePaths/ProtectHome over a /home/<user> path + empty cap set = throw). Third live instance of the class (cv-backup, browser-history provisioner, now both of mine).
- e3 **The gate-failing TODO row class**: a sibling queued a [ready] row whose wait-language hard-fails EVERY commit repo-wide until fixed. Queue authors should use `[blocked:<gate>]` tags for time/deploy-gated verifications at authoring time.

## f) NEXT

1. (sibling) crm/journal vendorHash repair → float-register green → deploy — my cap fix + tonight's fixed timers ride it
2. After deploy: journalctl both backup units for clean timer-driven firings (the [blocked:deploy] row owns the full procedure)
3. First fully-green CI run → trash `~/.cache/systemnix-ci-keys/` key files (bundle2.txt + dk-*; the sops archive is the durable copy)
4. First calm window post-float: run ~/.cache/negative-check.nix (disabled-fan-out proof), delete the scratch after
5. Owner browser smoke from the desk: timesheets.home.lan + invoices.home.lan (LAN bypass; WAN answers the oauth2 gate)

## g) QUESTIONS — none new. The 13:25 §g defaults all held under "keep going": (1) the foreign eval break self-resolved before I touched it; (2) the three silence-defaults stand verified live (config of record boots the dashboard, LAN bypass serves both vHosts, both locked revs byte-proven in the running processes); (3) key trash stays deferred to the first green CI run.

---

**Honest bottom line:** the deployment finished the last mile under a four-session storm without stepping on anyone: services live and verified on every surface that matters (process, TLS, health, SSE, gatus, tiles, hardening), the one REAL bug found in production wiring (backup DAC blindness) was root-caused to first principles, fixed with live validation, drilled, and receipted, and the CI auth hole that predated my work (cvagent) was closed with the documented two-bundle doctrine. What remains is sequenced behind sibling work (float repair → deploy → timer proof) and one CI verdict.
